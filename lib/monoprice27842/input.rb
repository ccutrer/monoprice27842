module Monoprice27842
  class Input
    attr_reader :id, :link, :edid

    def initialize(id)
      @id = id
    end

    def update_link(val)
      @link = val
    end

    def update_edid(val)
      @edid = val
    end
  end
end
