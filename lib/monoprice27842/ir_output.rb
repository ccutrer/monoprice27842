# frozen_string_literal: true

module Monoprice27842
  class IROutput
    # ir_input is FROM HDMI outputs
    attr_reader :id, :ir_input

    def initialize(id, owner)
      @id = id
      @owner = owner
    end

    def ir_input=(val)
      @owner.ir_output_input(val, output: id)
    end

    def update_ir_input(val)
      @ir_input = val
    end
  end
end
