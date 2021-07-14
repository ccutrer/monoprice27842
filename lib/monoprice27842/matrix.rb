# frozen_string_literal: true

require 'io/wait'

module Monoprice27842
  class Matrix
    attr_reader :name, :type, :version, :cpld_version, :video_driver_version,
                :power, :hdbt_poc, :front_panel_lock, :ip, :ir_follow_video,
                :inputs, :hdbt_outputs, :hdmi_outputs, :analog_outputs,
                :spdif_outputs, :ir_outputs, :presets
    attr_accessor :item_updated_proc

    EDIDS = [
      '1080p 2CH',
      '1080p MultiCH',
      '4K@30Hz HDR 2CH',
      '4K@30Hz HDR MultiCH',
      '4K@60Hz HDR 2CH',
      '4K@60Hz HDR MultiCH',
      'User-defined'
    ].freeze

    def initialize(uri)
      uri = URI.parse(uri)
      @io = case uri.scheme
            when 'tcp'
              require 'socket'
              TCPSocket.new(uri.host, uri.port)
            when 'telnet', 'rfc2217'
              require 'net/telnet/rfc2217'
              Net::Telnet::RFC2217.new('Host' => uri.host, 'Port' => uri.port || 23, 'baud' => 9600)
            else
              require 'ccutrer-serialport'
              CCutrer::SerialPort.new(uri.path, baud: 9600, data_bits: 8, parity: :none, stop_bits: 1)
            end

      @inputs = (1..8).map { |id| Input.new(id) }
      @hdbt_outputs = (1..8).map { |id| HDBTOutput.new(id, self) }
      @hdmi_outputs = (1..8).map { |id| HDMIOutput.new(id, self) }
      @analog_outputs = (1..8).map { |id| AnalogOutput.new(id, self) }
      @spdif_outputs = (1..8).map { |id| SPDIFOutput.new(id, self) }
      @ir_outputs = (1..8).map { |id| IROutput.new(id, self) }
      @presets = (1..8).map { |id| Preset.new(id, self) }
      @mutex = Mutex.new

      # empty any trash recently sent
      @io.readbyte while @io.ready?

      @next_message = ->(m) { @name = m }
      write_and_wait('/*Name.', wait: 5)
      unless @name
        @next_message = nil
        turned_on = true
        write_and_wait('PowerON.')
        read_messages(lag: 0.1)
        @next_message = ->(m) { @name = m }
        write_and_wait('/*Name.')
      end
      @next_message = ->(m) { @type = m }
      write_and_wait('/*Type.')
      write_and_wait('/^Version.')
      write('STA.')
      (1..9).each do |i|
        write(format('PresetSta%02d.', i))
      end
      read_messages(lag: turned_on ? 0.5 : 0.1)
      write_and_wait('PowerOFF.') if turned_on
    end

    def wait_readable(*args)
      result = @io.wait_readable(*args)
      return self if result == @io

      result
    end

    def refresh
      return unless power

      synchronize do
        write_and_wait('STA_IN.')
        write_and_wait('STA_OUT.')
      end
    end

    def read_messages(wait: true, lag: nil)
      if lag
        # keep reading messages until there's a bit of a lag between
        read_messages(wait: false)
        loop do
          break if wait_readable(lag).nil?

          read_messages
        end
        return
      end

      return if !wait && @io.ready?
      return if wait.is_a?(Numeric) && @io.wait_readable(wait).nil?

      synchronize do
        buffer = +''
        count = 0
        loop do
          buffer.concat(@io.readpartial(65_536)) while @io.ready?

          unless buffer[-1] == "\n"
            @io.wait_readable
            next
          end

          buffer.split("\r\n").each do |message|
            next if message.empty?

            got_message(message)
            count += 1
          end
          buffer = +''

          break unless @io.ready?
        end
        count
      end
    end

    def power=(value)
      raise ArgumentError unless [true, false].include?(value)

      write("Power#{value ? 'ON' : 'OFF'}.")
    end

    def hdbt_poc=(value)
      raise ArgumentError unless [true, false].include?(value)

      write("PHDBT#{value ? 'ON' : 'OFF'}.")
    end

    def front_panel_lock=(value)
      raise ArgumentError unless [true, false].include?(value)

      write(value ? 'Lock.' : 'Unlock.')
    end

    def ip=(value)
      raise ArgumentError unless value =~ /^(?:\d{1,3}\.){3}\d{1,3}$/

      write("SetGuiIP:#{value}.")
    end

    def ir_follow_video=(value)
      raise ArgumentError unless [true, false].include?(value)

      write("IRFV#{value ? 'ON' : 'OFF'}.")
    end

    def output_power(value, output: 0)
      raise ArgumentError unless [true, false].include?(value)
      raise ArgumentError unless (0..16).include?(output)

      write(format('%sOUT%02d.', value ? '@' : '$', output))
    end

    def output_hdcp(value, output: 0)
      raise ArgumentError unless %i[match_display passive bypass].include?(value)
      raise ArgumentError unless (0..16).include?(output)

      write(format('HDCP%02d%s.', output, value.to_s[0..2].upcase))
    end

    def hdbt_output_input(value, output: 0)
      raise ArgumentError unless (1..8).include?(value)
      raise ArgumentError unless (0..8).include?(output)

      write(format('OUT%02d:%02d.', output, value))
    end

    def hdbt_output_downscale(value, output: 0)
      raise ArgumentError unless [true, false].include?(value)
      raise ArgumentError unless (0..8).include?(output)

      write(format('DS%02d%s.', output, value ? 'ON' : 'OFF'))
    end

    def hdbt_output_rs232_remote_control_mcu(value, output: 0)
      raise ArgumentError unless [true, false].include?(value)
      raise ArgumentError unless (0..8).include?(output)

      write(format('RS232RCM%02d%s.', output, value ? 'ON' : 'OFF'))
    end

    def hdbt_output_ir_remote_control_mcu(value, output: 0)
      raise ArgumentError unless [true, false].include?(value)
      raise ArgumentError unless (0..8).include?(output)

      write(format('IRRCM%02d%s.', output, value ? 'ON' : 'OFF'))
    end

    def analog_output_input(value, output: 0)
      raise ArgumentError unless value.to_s =~ /^(in|out)([1-8])$/
      raise ArgumentError unless (0..8).include?(output)

      value = $2.to_i
      value += 8 if $1 == 'out'
      write(format('ANALOG%02d:%02d.', output, value))
    end

    def analog_output_mute(value, output: 0)
      raise ArgumentError unless [true, false].include?(value)
      raise ArgumentError unless (0..8).include?(output)

      write(format('AVOLUME%02d:%s.', output, value ? 'MU' : 'UM'))
    end

    def analog_output_volume(value, output: 0)
      raise ArgumentError unless %i[up down].include?(value) || (0..100).include?(value)
      raise ArgumentError unless (0..8).include?(output)

      value = case value
              when :up then 'V+'
              when :down then 'V-'
              else; format('%02d', value)
              end
      write(format('AVOLUME%02d:%s.', output, value))
    end

    def spdif_output_input(value, output: 0)
      raise ArgumentError unless value.to_s =~ /^(in|out|arc)([1-8])$/
      raise ArgumentError unless (0..8).include?(output)

      value = $2.to_i
      value += 8 if $1 == 'out'
      value += 16 if $1 == 'arc'
      write(format('SPDIF%02d:%02d.', output, value))
    end

    def ir_output_input(value, output: 0)
      raise ArgumentError unless (1..8).include?(value)
      raise ArgumentError unless (0..8).include?(output)

      write(format('IR%02d:%02d.', output, value))
    end

    private

    def write(message)
      synchronize do
        if power == false && message != 'PowerON.'
          puts "dropping #{message.inspect}"
          return
        end
        puts "writing #{message.inspect}"
        @io.write(message)
      end
    end

    def write_and_wait(message, wait: true)
      synchronize do
        write(message)
        read_messages(wait: wait)
      end
    end

    def got_message(message)
      puts message.inspect

      if @next_message
        @next_message.call(message)
        @next_message = nil
        return
      end

      case message
      when 'GUI Or RS232 Query Status:'
      when @name
      when @type
      when /^V(\d+\.\d+\.\d+)$/
        @version = $1
        item_updated_proc&.call(self, :version)
      when /^CPLD:V(\d+\.\d+\.\d+)$/
        @cpld_version = $1
        item_updated_proc&.call(self, :cpld_version)
      when /^VideoDriverVersion:V(\d+\.\d+\.\d+)$/
        @video_driver_version = $1
        item_updated_proc&.call(self, :video_driver_version)
      when /^Power (ON|OFF)!$/
        @power = $1 == 'ON'
        item_updated_proc&.call(self, :power)
      when /^HDBT Power (ON|OFF)!$/
        @hdbt_poc = $1 == 'ON'
        item_updated_proc&.call(self, :hdbt_poc)
      when /^Front Panel (Locked|UnLock)!$/
        @front_panel_lock = $1 == 'Locked'
        item_updated_proc&.call(self, :front_panel_lock)
      when /^Local RS232 Baudrate Is (\d+)!$/
        # Ignore
      when /^GUI_IP:((?:\d{1,3}\.){3}\d{1,3})!$/
        @ip = $1
        item_updated_proc&.call(self, :ip)
      when /^Output (\d{2}) Switch To In (\d{2})!$/
        obj = hdbt_outputs[$1.to_i - 1]
        obj.update_input($2.to_i)
        item_updated_proc&.call(obj, :input)
      when /^Turn (ON|OFF) Output (\d{2})!$/
        obj = find_hdmi_output($2.to_i)
        obj.update_power($1 == 'ON')
        item_updated_proc&.call(obj, :power)
      when /^HDMI OUT (\d{2}) Down Scale (ON|OFF)!$/
        obj = hdbt_outputs[$1.to_i - 1]
        obj.update_downscale($2 == 'ON')
        item_updated_proc&.call(obj, :downscale)
      when /^RS232 Remote (\d{2}) Control MCU (ON|OFF)!$/
        obj = hdbt_outputs[$1.to_i - 1]
        obj.update_rs232_remote_control_mcu($2 == 'ON')
        item_updated_proc&.call(obj, :rs232_remote_control_mcu)
      when /^IR Remote (\d{2}) Control MCU (ON|OFF)!$/
        obj = hdbt_outputs[$1.to_i - 1]
        obj.update_ir_remote_control_mcu($2 == 'ON')
        item_updated_proc&.call(obj, :ir_remote_control_mcu)
      when /^Analog Out (\d{2}) Switch To Video (In|Out) (\d{2})!$/
        obj = analog_outputs[$1.to_i - 1]
        obj.update_input("#{$2.downcase}#{$3.to_i}".to_sym)
        item_updated_proc&.call(obj, :input)
      when /^Analog Out (\d{2}) Volume (Un)?Mute!$/
        obj = analog_outputs[$1.to_i - 1]
        obj.update_mute($2.nil?)
        item_updated_proc&.call(obj, :mute)
      when /^Analog Out (\d{2}) Volume (\d+)!$/
        obj = analog_outputs[$1.to_i - 1]
        obj.update_volume($2.to_i)
        item_updated_proc&.call(obj, :volume)
      when /^SPDIF Out (\d{2}) Switch To (ARC|Video In|Video Out) (\d{2})!$/
        obj = spdif_outputs[$1.to_i - 1]
        obj.update_input("#{$2[-3..-1].strip.downcase}#{$3.to_i}".to_sym)
        item_updated_proc&.call(obj, :input)
      when /^IR Follow Video (ON|OFF)!$/
        @ir_follow_video = $1 == 'ON'
        item_updated_proc&.call(self, :ir_follow_video)
      when /^Local (\d{2}) IR Out Switch To Remote (\d{2}) IR IN!$/
        obj = ir_outputs[$1.to_i - 1]
        obj.update_ir_input($2.to_i)
        item_updated_proc&.call(obj, :ir_input)
      when 'IN   1  2  3  4  5  6  7  8'
      when /^LINK ((?:Y|N)(?:  (?:Y|N)){7})$/
        $1.split('  ').each_with_index do |link, i|
          obj = inputs[i]
          obj.update_link(link == 'Y')
          item_updated_proc&.call(obj, :link)
        end
      when 'OUT  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16'
      when /^LINK ((?:Y|N)(?:  (?:Y|N)){15})$/
        $1.split('  ').each_with_index do |link, i|
          obj = find_hdmi_output(i + 1)
          obj.update_link(link == 'Y')
          item_updated_proc&.call(obj, :link)
        end
      when /^Input (\d{2}) EDID (?:Upgrade OK By|From) (\d{2}) Internal EDID!$/
        obj = inputs[$1.to_i - 1]
        obj.update_edid(EDIDS[$2.to_i - 1])
        item_updated_proc&.call(obj, :edid)
      when /^OUT (\d{2}) HDCP (MAT Display|PASSIVE|BYPASSS?)!$/i
        hdcp = $2.downcase.to_sym
        hdcp = :match_display if hdcp == :"mat display"
        hdcp = :bypass if hdcp == :bypasss
        obj = find_hdmi_output($1.to_i)
        obj.update_hdcp(hdcp)
        item_updated_proc&.call(obj, :hdcp)
      when /^Preset (\d{2}) Sta:$/
        @current_preset = $1.to_i - 1
      when /^Out (\d{2}) in (\d{2})!$/
        obj = presets[@current_preset]
        obj[$1.to_i - 1] = $2.to_i
        item_updated_proc&.call(obj, $1.to_i - 1)
      else
        puts "unrecognized message #{message.inspect}"
      end
    end

    def find_hdmi_output(output)
      if output > 8
        hdmi_outputs[output - 8 - 1]
      else
        hdbt_outputs[output - 1]
      end
    end

    def synchronize(&block)
      return yield if @mutex.owned?

      @mutex.synchronize(&block)
    end
  end
end
