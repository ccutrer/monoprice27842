# frozen_string_literal: true

module Monoprice27842
  class HDBTOutput < HDMIOutput
    attr_reader :input, :downscale, :rs232_remote_control_mcu, :ir_remote_control_mcu

    def input=(val)
      @owner.hdbt_output_input(val, output: id)
    end

    def downscale=(val)
      @owner.hdbt_output_downscale(val, output: id)
    end

    def rs232_remote_control_mcu=(val)
      @owner.hdbt_output_rs232_remote_control_mcu(val, output: id)
    end

    def ir_remote_control_mcu=(val)
      @owner.hdbt_output_ir_remote_control_mcu(val, output: id)
    end

    def update_input(val)
      @input = val
    end

    def update_downscale(val)
      @downscale = val
    end

    def update_rs232_remote_control_mcu(val)
      @rs232_remote_control_mcu = val
    end

    def update_ir_remote_control_mcu(val)
      @ir_remote_control_mcu = val
    end

    protected

    def effective_id
      id
    end
  end
end
