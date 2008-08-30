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

class StateMachineAfterCreatedTest < Test::Unit::TestCase
  def setup
    machine = Switch.state_machine(:state, :initial => 'off')
    
    machine.before_exit 'off', Proc.new {|switch, value| switch.callbacks << 'before_exit'}
    machine.before_enter 'off', Proc.new {|switch, value| switch.callbacks << 'before_enter'}
    machine.after_exit 'off', Proc.new {|switch, value| switch.callbacks << 'after_exit'}
    machine.after_enter 'off', Proc.new {|switch, value| switch.callbacks << 'after_enter'}
    
    @switch = create_switch
  end
  
  def test_should_invoke_after_enter_callbacks_for_initial_state
    assert_equal %w(after_enter), @switch.callbacks
  end
  
  def teardown
    Switch.write_inheritable_attribute(:state_machines, {})
    
    Switch.class_eval do
      @transition_on_turn_on_callbacks = nil
      @transition_bang_on_turn_on_callbacks = nil
      @before_exit_state_off_callbacks = nil
      @before_enter_state_on_callbacks = nil
      @after_exit_state_off_callbacks = nil
      @after_enter_state_on_callbacks = nil
    end
  end
end

class StateMachineWithSubclassTest < Test::Unit::TestCase
  def setup
    Switch.state_machine(:state, :initial => 'on')
    ToggleSwitch.state_machine(:state, :initial => 'off')
  end
  
  def test_should_be_able_to_override_initial_state
    assert_equal 'on', Switch.new.state
    assert_equal 'off', ToggleSwitch.new.state
  end
  
  def teardown
    Switch.write_inheritable_attribute(:state_machines, {})
    ToggleSwitch.write_inheritable_attribute(:state_machines, {})
  end
end
