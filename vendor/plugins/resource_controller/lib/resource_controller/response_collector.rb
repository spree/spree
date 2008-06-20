module ResourceController
  class ResponseCollector
    
    attr_reader :responses
    
    delegate :clear, :to => :responses
    
    def initialize
      @responses = []
    end
    
    def method_missing(method_name, &block)
      @responses.delete self[method_name]
      @responses << [method_name, block || nil]
    end
    
    def [](symbol)
      @responses.find { |method, block| method == symbol }
    end
  end
end