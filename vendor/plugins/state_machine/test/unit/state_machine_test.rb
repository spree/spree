require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StateMachineTest < Test::Unit::TestCase
  def test_should_track_all_state_machines
    @machine = Switch.state_machine(:state)
    assert_equal @machine, Switch.state_machines['state']
  end
  
  def test_should_allow_multiple_state_machines
    @machine = Switch.state_machine(:state)
    @second_machine = Switch.state_machine(:kind)
    assert_equal 2, Switch.state_machines.size
  end
  
  def test_should_evaluate_block_within_event_context
    responded = false
    Switch.state_machine(:state) do
      responded = respond_to?(:event)
    end
    
    assert responded
  end
  
  def teardown
    Switch.write_inheritable_attribute(:state_machines, {})
  end
end

class StateMachineAfterInitializedTest < Test::Unit::TestCase
  def setup
    Switch.state_machine(:state, :initial => 'off')
  end
  
  def test_should_set_the_initial_state
    assert_equal 'off', Switch.new.state
  end
  
  def test_should_not_set_the_initial_state_if_specified
    assert_equal 'on', Switch.new(:state => 'on').state
  end
  
  def test_should_not_set_the_initial_state_if_specified_as_string
    assert_equal 'on', Switch.new('state' => 'on').state
  end
  
  def test_should_allow_evaluation_block_during_initialization
    evaluated = false
    Switch.new do
      evaluated = true
    end
    
    assert evaluated
  end
  
  def teardown
    Switch.write_inheritable_attribute(:state_machines, {})
  end
end

class StateMachineAfterInitializedWithDynamicInitialStateTest < Test::Unit::TestCase
  def setup
    Switch.state_machine(:state, :initial => Proc.new {|record| record.initial_state})
  end
  
  def test_should_set_the_initial_state_based_on_the_record
    assert_equal 'off', Switch.new(:initial_state => 'off').state
    assert_equal 'on', Switch.new(:initial_state => 'on').state
  end
  
  def teardown
    Switch.write_inheritable_attribute(:state_machines, {})
  end
end

class StateMachineWithSubclassTest < Test::Unit::TestCase
  def setup
    @machine = Switch.state_machine(:state, :initial => 'on') do
      event :turn_on do
        transition :to => 'on', :from => 'off'
      end
    end
    
    # Need to add this since the state machine isn't defined directly within the
    # class
    ToggleSwitch.write_inheritable_attribute :state_machines, {'state' => @machine}
    
    @new_machine = ToggleSwitch.state_machine(:state, :initial => 'off') do
      event :turn_on do
        transition :to => 'off', :from => 'on'
      end
      
      event :replace do
        transition :to => 'under_repair', :from => 'off'
      end
    end
  end
  
  def test_should_not_have_the_same_machine_as_the_superclass
    assert_not_same @machine, @new_machine
  end
  
  def test_should_use_new_initial_state
    assert_equal 'off', @new_machine.initial_state(new_switch)
  end
  
  def test_should_not_change_original_initial_state
    assert_equal 'on', @machine.initial_state(new_switch)
  end
  
  def test_should_define_new_events_on_subclass
    assert new_toggle_switch.respond_to?(:replace)
  end
  
  def test_should_not_define_new_events_on_superclass
    assert !new_switch.respond_to?(:replace)
  end
  
  def test_should_define_new_transitions_on_subclass
    assert_equal 2, @new_machine.events['turn_on'].transitions.length
  end
  
  def test_should_not_define_new_transitions_on_superclass
    assert_equal 1, @machine.events['turn_on'].transitions.length
  end
  
  def teardown
    Switch.write_inheritable_attribute(:state_machines, {})
    ToggleSwitch.write_inheritable_attribute(:state_machines, {})
  end
end
