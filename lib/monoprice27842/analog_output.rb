# frozen_string_literal: true

module Monoprice27842
  class AnalogOutput
    attr_reader :id, :input, :mute, :volume

    def initialize(id, owner)
      @id = id
      @owner = owner
    end

    def input=(val)
      @owner.analog_output_input(val, output: id)
    end

    def mute=(val)
      @owner.analog_output_mute(val, output: id)
    end

    def volume=(val)
      @owner.analog_output_volume(val, output: id)
    end

    def update_input(val)
      @input = val
    end

    def update_mute(val)
      @mute = val
    end

    def update_volume(val)
      @volume = val
    end
  end
end
