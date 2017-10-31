module Spree
  class ActionCallbacks
    attr_reader :before_methods
    attr_reader :after_methods
    attr_reader :fails_methods

    def initialize
      @before_methods = []
      @after_methods = []
      @fails_methods = []
    end

    def before(method)
      @before_methods << method
    end

    def after(method)
      @after_methods << method
    end

    def fails(method)
      @fails_methods << method
    end
  end
end
