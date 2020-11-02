module Monoprice27842
  class SPDIFOutput
    attr_reader :id, :input

    def initialize(id, owner)
      @id = id
      @owner = owner
    end

    def input=(val)
      @owner.spdif_output_input(val, output: id)
    end

    def update_input(val)
      @input = val
    end
  end
end
