module ResourceController
  class ActionOptions
    extend ResourceController::Accessors
    
    reader_writer  :flash
    reader_writer  :flash_now
    
    block_accessor :after, :before
    
    def initialize
      @collector = ResourceController::ResponseCollector.new
    end
    
    def response(*args, &block)
      if !args.empty? || block_given?
        @collector.clear
        args.flatten.each { |symbol| @collector.send(symbol) }
        block.call(@collector) if block_given?
      end
      
      @collector.responses
    end
    alias_method :respond_to,  :response
    alias_method :responds_to, :response
    
    def wants
      @collector
    end
    
    def dup
      returning self.class.new do |duplicate|
        duplicate.instance_variable_set(:@collector, wants.dup)
        duplicate.instance_variable_set(:@before, before.dup)       unless before.nil?
        duplicate.instance_variable_set(:@after, after.dup)         unless after.nil?
        duplicate.instance_variable_set(:@flash, flash.dup)         unless flash.nil?
        duplicate.instance_variable_set(:@flash_now, flash_now.dup) unless flash_now.nil?
      end
    end
  end
end