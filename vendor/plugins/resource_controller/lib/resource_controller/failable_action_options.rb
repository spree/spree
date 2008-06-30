module ResourceController
  class FailableActionOptions
    extend ResourceController::Accessors
    
    scoping_reader :success, :fails
    alias_method :failure, :fails
    
    block_accessor :before
    
    def initialize
      @success = ActionOptions.new
      @fails   = ActionOptions.new
    end
    
    delegate :flash, :flash_now, :after, :response, :wants, :to => :success
    
    def dup
      returning self.class.new do |duplicate|
        duplicate.instance_variable_set(:@success, success.dup)
        duplicate.instance_variable_set(:@fails,   fails.dup)
        duplicate.instance_variable_set(:@before,  before.dup) unless before.nil?
      end
    end
  end
end