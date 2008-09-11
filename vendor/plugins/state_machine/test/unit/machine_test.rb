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

class MachineWithInitialStateTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
  end
  
  def test_should_have_an_initial_state
    assert_equal 'off', @machine.initial_state(new_switch)
  end
end

class MachineWithDynamicInitialStateTest < Test::Unit::TestCase
  def setup
    @initial_state = lambda {|switch| switch.initial_state}
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => @initial_state)
  end
  
  def test_should_use_the_record_for_determining_the_initial_state
    assert_equal 'off', @machine.initial_state(new_switch(:initial_state => 'off'))
    assert_equal 'on', @machine.initial_state(new_switch(:initial_state => 'on'))
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
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {PluginAWeek::StateMachine::Machine.new(Switch, 'state', :invalid => true)}
  end
  
  def test_should_symbolize_attribute
    machine = PluginAWeek::StateMachine::Machine.new(Switch, :state)
    assert_equal 'state', machine.attribute
  end
end

class MachineAfterBeingCopiedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @machine.event(:turn_on) {}
    
    @copied_machine = @machine.dup
  end
  
  def test_should_not_have_the_same_collection_of_states
    assert_not_same @copied_machine.states, @machine.states
  end
  
  def test_should_not_have_the_same_collection_of_events
    assert_not_same @copied_machine.events, @machine.events
  end
  
  def test_should_copy_each_event
    assert_not_same @copied_machine.events['turn_on'], @machine.events['turn_on']
  end
  
  def test_should_update_machine_for_each_event
    assert_equal @copied_machine, @copied_machine.events['turn_on'].machine
  end
  
  def test_should_not_update_machine_for_original_event
    assert_equal @machine, @machine.events['turn_on'].machine
  end
end

class MachineAfterChangingContextTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
  end
  
  def test_should_create_copy_of_machine
    new_machine = @machine.within_context(ToggleSwitch)
    assert_not_same @machine, new_machine
  end
  
  def test_should_update_owner_clas
    new_machine = @machine.within_context(ToggleSwitch)
    assert_equal ToggleSwitch, new_machine.owner_class
  end
  
  def test_should_update_initial_state
    new_machine = @machine.within_context(ToggleSwitch, :initial => 'off')
    assert_equal 'off', new_machine.initial_state(new_switch)
  end
  
  def test_should_not_update_initial_state_if_not_provided
    new_machine = @machine.within_context(ToggleSwitch)
    assert_nil new_machine.initial_state(new_switch)
  end
  
  def test_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {@machine.within_context(ToggleSwitch, :invalid => true)}
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

class MachineWithExistingEventTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = @machine.event(:turn_on) {}
    @same_event = @machine.event(:turn_on) {}
  end
  
  def test_should_not_create_new_event
    assert_same @event, @same_event
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
  
  def test_should_track_states_defined_in_event_transitions
    assert_equal %w(error off on unknown), @machine.states
  end
  
  def test_should_not_duplicate_states_defined_in_multiple_event_transitions
    @machine.event :turn_off do
      transition :to => 'off', :from => 'on'
    end
    
    assert_equal %w(error off on unknown), @machine.states
  end
end

class MachineWithTransitionCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = @machine.event :turn_on do
      transition :to => 'on', :from => 'off'
    end
    
    @switch = create_switch(:state => 'off')
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {@machine.before_transition :invalid => true}
  end
  
  def test_should_raise_exception_if_do_option_not_specified
    assert_raise(ArgumentError) {@machine.before_transition :to => 'on'}
  end
  
  def test_should_invoke_callbacks_during_transition
    @machine.before_transition lambda {|switch| switch.callbacks << 'before'}
    @machine.after_transition lambda {|switch| switch.callbacks << 'after'}
    
    @event.fire(@switch)
    assert_equal %w(before after), @switch.callbacks
  end
  
  def test_should_support_from_query
    @machine.before_transition :from => 'off', :do => lambda {|switch| switch.callbacks << 'off'}
    @machine.before_transition :from => 'on', :do => lambda {|switch| switch.callbacks << 'on'}
    
    @event.fire(@switch)
    assert_equal %w(off), @switch.callbacks
  end
  
  def test_should_support_except_from_query
    @machine.before_transition :except_from => 'off', :do => lambda {|switch| switch.callbacks << 'off'}
    @machine.before_transition :except_from => 'on', :do => lambda {|switch| switch.callbacks << 'on'}
    
    @event.fire(@switch)
    assert_equal %w(on), @switch.callbacks
  end
  
  def test_should_support_to_query
    @machine.before_transition :to => 'off', :do => lambda {|switch| switch.callbacks << 'off'}
    @machine.before_transition :to => 'on', :do => lambda {|switch| switch.callbacks << 'on'}
    
    @event.fire(@switch)
    assert_equal %w(on), @switch.callbacks
  end
  
  def test_should_support_except_to_query
    @machine.before_transition :except_to => 'off', :do => lambda {|switch| switch.callbacks << 'off'}
    @machine.before_transition :except_to => 'on', :do => lambda {|switch| switch.callbacks << 'on'}
    
    @event.fire(@switch)
    assert_equal %w(off), @switch.callbacks
  end
  
  def test_should_support_on_query
    @machine.before_transition :on => 'turn_off', :do => lambda {|switch| switch.callbacks << 'turn_off'}
    @machine.before_transition :on => 'turn_on', :do => lambda {|switch| switch.callbacks << 'turn_on'}
    
    @event.fire(@switch)
    assert_equal %w(turn_on), @switch.callbacks
  end
  
  def test_should_support_except_on_query
    @machine.before_transition :except_on => 'turn_off', :do => lambda {|switch| switch.callbacks << 'turn_off'}
    @machine.before_transition :except_on => 'turn_on', :do => lambda {|switch| switch.callbacks << 'turn_on'}
    
    @event.fire(@switch)
    assert_equal %w(turn_off), @switch.callbacks
  end
  
  def teardown
    Switch.class_eval do
      @before_transition_state_callbacks = nil
      @after_transition_state_callbacks = nil
    end
  end
end
