# frozen_string_literal: true

module Monoprice27842
  class HDMIOutput
    attr_reader :id, :power, :link, :hdcp

    def initialize(id, owner)
      @id = id
      @owner = owner
    end

    def power=(val)
      @owner.output_power(val, output: effective_id)
    end

    def hdcp=(val)
      @owner.output_hdcp(val, output: effective_id)
    end

    def update_power(val)
      @power = val
    end

    def update_link(val)
      @link = val
    end

    def update_hdcp(val)
      @hdcp = val
    end

    protected

    def effective_id
      id + 8
    end
  end
end
