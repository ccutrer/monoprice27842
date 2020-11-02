module Monoprice27842
  class Preset < Array
    attr_reader :id

    def initialize(id, owner)
      @id = id
      @owner = owner
      clear
    end

    def clear
      super
      self[7] = nil
    end
  end
end
