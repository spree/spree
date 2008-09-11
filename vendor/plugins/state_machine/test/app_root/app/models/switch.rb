class Switch < ActiveRecord::Base
  # Tracks the callbacks that were invoked
  attr_reader :callbacks
  
  # Dynamic sets the initial state
  attr_accessor :initial_state
  
  # Whether or not validations should fail
  attr_accessor :fail_validation
  validate Proc.new {|switch| switch.errors.add_to_base 'is invalid' if switch.fail_validation}
  
  # Whether or not saves should fail
  attr_accessor :fail_save
  before_save Proc.new {|switch| !switch.fail_save}
  
  # Arbitrary data associated with the switch
  attr_accessor :data
  
  def initialize(attributes = nil)
    @callbacks = []
    super
  end
end
