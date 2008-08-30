require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MachineByDefaultTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch)
  end
  
  def test_should_have_an_attribute
    assert_equal 'state', @machine.attribute
  end
  
  def test_should_not_have_an_initial_state
    assert_nil @machine.initial_state(new_switch)
  end
  
  def test_should_have_an_owner_class
    assert_equal Switch, @machine.owner_class
  end
  
  def test_should_not_have_any_events
    assert @machine.events.empty?
  end
  
  def test_should_not_have_any_states
    assert @machine.states.empty?
  end
end

class MachineWithInvalidOptionsTest < Test::Unit::TestCase
  def test_should_throw_an_exception
    assert_raise(ArgumentError) {PluginAWeek::StateMachine::Machine.new(Switch, 'state', :invalid => true)}
  end
end

class MachineWithInitialStateTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
  end
  
  def test_should_have_an_initial_state
    assert_equal 'off', @machine.initial_state(new_switch)
  end
  
  def test_should_have_an_initial_state_without_processing
    assert_equal 'off', @machine.initial_state_without_processing
  end
end

class MachineWithDynamicInitialStateTest < Test::Unit::TestCase
  def setup
    @initial_state = Proc.new {|switch| switch.initial_state}
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => @initial_state)
  end
  
  def test_should_use_the_record_for_determining_the_initial_state
    assert_equal 'off', @machine.initial_state(new_switch(:initial_state => 'off'))
    assert_equal 'on', @machine.initial_state(new_switch(:initial_state => 'on'))
  end
  
  def test_should_have_an_initial_state_without_processing
    assert_equal @initial_state, @machine.initial_state_without_processing
  end
end

class MachineTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
  end
  
  def test_should_define_a_named_scope_for_the_attribute
    on = create_switch(:state => 'on')
    off = create_switch(:state => 'off')
    
    assert_equal [on], Switch.with_state('on')
  end
  
  def test_should_define_a_pluralized_named_scope_for_the_attribute
    on = create_switch(:state => 'on')
    off = create_switch(:state => 'off')
    
    assert_equal [on, off], Switch.with_states('on', 'off')
  end
end

class MachineWithConflictingNamedScopesTest < Test::Unit::TestCase
  class Switch < ActiveRecord::Base
    def self.with_state
      :custom
    end
    
    def self.with_states
      :custom
    end
  end
  
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
  end
  
  def test_should_not_define_a_named_scope_for_the_attribute
    assert_equal :custom, Switch.with_state
  end
  
  def test_should_not_define_a_pluralized_named_scope_for_the_attribute
    assert_equal :custom, Switch.with_states
  end
end

class MachineWithEventsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
  end
  
  def test_should_create_event_with_given_name
    event = @machine.event(:turn_on) {}
    assert_equal 'turn_on', event.name
  end
  
  def test_should_evaluate_block_within_event_context
    responded = false
    @machine.event :turn_on do
      responded = respond_to?(:transition)
    end
    
    assert responded
  end
  
  def test_should_have_events
    @machine.event(:turn_on) {}
    assert_equal %w(turn_on), @machine.events.keys
  end
end

class MachineWithEventsAndTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @machine.event(:turn_on) do
      transition :to => 'on', :from => 'off'
      transition :to => 'error', :from => 'unknown'
    end
  end
  
  def test_should_have_events
    assert_equal %w(turn_on), @machine.events.keys
  end
  
  def test_should_have_states
    assert_equal %w(on off error unknown), @machine.states
  end
end

class MachineWithStateCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @machine.before_exit 'off', Proc.new {|switch, value| switch.callbacks << 'before_exit'}
    @machine.before_enter 'on', Proc.new {|switch, value| switch.callbacks << 'before_enter'}
    @machine.after_exit 'off', Proc.new {|switch, value| switch.callbacks << 'after_exit'}
    @machine.after_enter 'on', Proc.new {|switch, value| switch.callbacks << 'after_enter'}
    
    @event = @machine.event :turn_on do
      transition :to => 'on', :from => 'off'
    end
    
    @switch = create_switch(:state => 'off')
  end
  
  def test_should_invoke_callbacks_during_transition
    @event.fire(@switch)
    assert_equal %w(before_exit before_enter after_exit after_enter), @switch.callbacks
  end
  
  def teardown
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
