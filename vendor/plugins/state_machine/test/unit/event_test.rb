require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EventTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
  end
  
  def test_should_have_a_machine
    assert_equal @machine, @event.machine
  end
  
  def test_should_have_a_name
    assert_equal 'turn_on', @event.name
  end
  
  def test_should_not_have_any_transitions
    assert @event.transitions.empty?
  end
  
  def test_should_define_an_event_action_on_the_owner_class
    switch = new_switch
    assert switch.respond_to?(:turn_on)
  end
  
  def test_should_define_an_event_bang_action_on_the_owner_class
    switch = new_switch
    assert switch.respond_to?(:turn_on!)
  end
  
  def test_should_define_transition_callbacks
    assert Switch.respond_to?(:transition_on_turn_on)
  end
  
  def test_should_define_transition_bang_callbacks
    assert Switch.respond_to?(:transition_bang_on_turn_on)
  end
  
  def test_should_define_before_event_callbacks
    assert Switch.respond_to?(:before_turn_on)
  end
  
  def test_should_define_after_event_callbacks
    assert Switch.respond_to?(:after_turn_on)
  end
end

class EventWithInvalidOptionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
  end
  
  def test_should_raise_exception
    assert_raise(ArgumentError) {PluginAWeek::StateMachine::Event.new(@machine, 'turn_on', :invalid => true)}
  end
end

class EventWithTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {@event.transition(:invalid => true)}
  end
  
  def test_should_raise_exception_if_to_option_not_specified
    assert_raise(ArgumentError) {@event.transition(:from => 'off')}
  end
  
  def test_should_not_raise_exception_if_from_option_not_specified
    assert_nothing_raised {@event.transition(:to => 'on')}
  end
  
  def test_should_allow_transitioning_without_a_state
    assert @event.transition(:to => 'on')
  end
  
  def test_should_allow_transitioning_from_a_single_state
    assert @event.transition(:to => 'on', :from => 'off')
  end
  
  def test_should_allow_transitioning_from_multiple_states
    assert @event.transition(:to => 'on', :from => %w(off on))
  end
  
  def test_should_have_transitions
    @event.transition(:to => 'on')
    assert @event.transitions.any?
  end
  
  def teardown
    Switch.class_eval do
      @transition_on_turn_on_callbacks = nil
      @transition_bang_on_turn_on_callbacks = nil
    end
  end
end

class EventAfterBeingFiredWithNoTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @switch = create_switch(:state => 'off')
  end
  
  def test_should_not_fire
    assert !@event.fire(@switch)
  end
  
  def test_should_not_change_the_current_state
    @event.fire(@switch)
    assert_equal 'off', @switch.state
  end
  
  def test_should_raise_exception_during_fire!
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@event.fire!(@switch)}
  end
end

class EventAfterBeingFiredWithTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition :to => 'error', :from => 'on'
    @switch = create_switch(:state => 'off')
  end
  
  def test_should_not_fire_if_no_transitions_are_matched
    assert !@event.fire(@switch)
    assert_equal 'off', @switch.state
  end
  
  def test_should_raise_exception_if_no_transitions_are_matched_during_fire!
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@event.fire!(@switch)}
    assert_equal 'off', @switch.state
  end
  
  def test_should_fire_if_transition_with_no_from_state_is_matched
    @event.transition :to => 'on'
    assert @event.fire(@switch)
    assert_equal 'on', @switch.state
  end
  
  def test_should_fire_if_transition_with_from_state_is_matched
    @event.transition :to => 'on', :from => 'off'
    assert @event.fire(@switch)
    assert_equal 'on', @switch.state
  end
  
  def test_should_fire_if_transition_with_multiple_from_states_is_matched
    @event.transition :to => 'on', :from => %w(off on)
    assert @event.fire(@switch)
    assert_equal 'on', @switch.state
  end
  
  def test_should_not_fire_if_validation_failed
    @event.transition :to => 'on', :from => 'off'
    @switch.fail_validation = true
    assert !@event.fire(@switch)
    
    @switch.reload
    assert_equal 'off', @switch.state
  end
  
  def test_should_raise_exception_if_validation_failed_during_fire!
    @event.transition :to => 'on', :from => 'off'
    @switch.fail_validation = true
    assert_raise(ActiveRecord::RecordInvalid) {@event.fire!(@switch)}
  end
  
  def test_should_not_fire_if_save_failed
    @event.transition :to => 'on', :from => 'off'
    @switch.fail_save = true
    assert !@event.fire(@switch)
    
    @switch.reload
    assert_equal 'off', @switch.state
  end
  
  def test_should_raise_exception_if_save_failed_during_fire!
    @event.transition :to => 'on', :from => 'off'
    @switch.fail_save = true
    assert_raise(ActiveRecord::RecordNotSaved) {@event.fire!(@switch)}
  end
  
  def test_should_not_raise_exception_if_transition_is_matched_during_fire!
    @event.transition :to => 'on', :from => 'off'
    assert @event.fire!(@switch)
    assert_equal 'on', @switch.state
  end
  
  def teardown
    Switch.class_eval do
      @transition_on_turn_on_callbacks = nil
      @transition_bang_on_turn_on_callbacks = nil
    end
  end
end

class EventAfterBeingFiredWithConditionalTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @switch = create_switch(:state => 'off')
  end
  
  def test_should_fire_if_if_is_true
    @event.transition :to => 'on', :from => 'off', :if => Proc.new {true}
    assert @event.fire(@switch)
  end
  
  def test_should_not_fire_if_if_is_false
    @event.transition :to => 'on', :from => 'off', :if => Proc.new {false}
    assert !@event.fire(@switch)
  end
  
  def test_should_fire_if_unless_is_false
    @event.transition :to => 'on', :from => 'off', :unless => Proc.new {false}
    assert @event.fire(@switch)
  end
  
  def test_should_not_fire_if_unless_is_true
    @event.transition :to => 'on', :from => 'off', :unless => Proc.new {true}
    assert !@event.fire(@switch)
  end
  
  def test_should_pass_in_record_as_argument
    @event.transition :to => 'on', :from => 'off', :if => Proc.new {|record, value| !record.nil?}
    assert @event.fire(@switch)
  end
  
  def test_should_pass_in_value_as_argument
    @event.transition :to => 'on', :from => 'off', :if => Proc.new {|record, value| value == 1}
    assert @event.fire(@switch, 1)
  end
  
  def test_should_fire_if_method_evaluates_to_true
    @switch.data = true
    @event.transition :to => 'on', :from => 'off', :if => :data
    assert @event.fire(@switch)
  end
  
  def test_should_not_fire_if_method_evaluates_to_false
    @switch.data = false
    @event.transition :to => 'on', :from => 'off', :if => :data
    assert !@event.fire(@switch)
  end
  
  def test_should_raise_exception_if_no_transitions_are_matched
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@event.fire!(@switch, 1)}
    assert_equal 'off', @switch.state
  end
  
  def test_should_not_raise_exception_if_transition_is_matched
    @event.transition :to => 'on', :from => 'off', :if => Proc.new {true}
    assert @event.fire!(@switch)
    assert_equal 'on', @switch.state
  end
  
  def teardown
    Switch.class_eval do
      @transition_on_turn_on_callbacks = nil
      @transition_bang_on_turn_on_callbacks = nil
    end
  end
end

class EventWithinTransactionTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition :to => 'on', :from => 'off'
    @switch = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_exit_state_off
  end
  
  def test_should_save_all_records_within_transaction_if_performed
    Switch.before_exit_state_off Proc.new {|record| Switch.create(:state => 'pending'); true}
    assert @event.fire(@switch)
    assert_equal 'on', @switch.state
    assert_equal 'pending', Switch.find(:all).last.state
  end
  
  uses_transaction :test_should_rollback_all_records_within_transaction_if_not_performed
  def test_should_rollback_all_records_within_transaction_if_not_performed
    Switch.before_exit_state_off Proc.new {|record| Switch.create(:state => 'pending'); false}
    assert !@event.fire(@switch)
    assert_equal 1, Switch.count
  ensure
    Switch.destroy_all
  end
  
  uses_transaction :test_should_rollback_all_records_within_transaction_if_not_performed!
  def test_should_rollback_all_records_within_transaction_if_not_performed!
    Switch.before_exit_state_off Proc.new {|record| Switch.create(:state => 'pending'); false}
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@event.fire!(@switch)}
    assert_equal 1, Switch.count
  ensure
    Switch.destroy_all
  end
  
  def teardown
    Switch.class_eval do
      @transition_on_turn_on_callbacks = nil
      @transition_bang_on_turn_on_callbacks = nil
      @before_exit_state_off_callbacks = nil
    end
  end
end

class EventWithCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition :from => 'off', :to => 'on'
    @record = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_turn_on, :after_turn_on
  end
  
  def test_should_not_perform_if_before_callback_fails
    Switch.before_turn_on Proc.new {|record| false}
    Switch.after_turn_on Proc.new {|record| record.callbacks << 'after'; true}
    
    assert !@event.fire(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_raise_exception_if_before_callback_fails_during_perform!
    Switch.before_turn_on Proc.new {|record| false}
    Switch.after_turn_on Proc.new {|record| record.callbacks << 'after'; true}
    
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@event.fire!(@record)}
    assert_equal [], @record.callbacks
  end
  
  def test_should_perform_if_after_callback_fails
    Switch.before_turn_on Proc.new {|record| record.callbacks << 'before'; true}
    Switch.after_turn_on Proc.new {|record| false}
    
    assert @event.fire(@record)
    assert_equal %w(before), @record.callbacks
  end
  
  def test_should_not_raise_exception_if_after_callback_fails_during_perform!
    Switch.before_turn_on Proc.new {|record| record.callbacks << 'before'; true}
    Switch.after_turn_on Proc.new {|record| false}
    
    assert @event.fire!(@record)
    assert_equal %w(before), @record.callbacks
  end
  
  def test_should_perform_if_all_callbacks_are_successful
    Switch.before_turn_on Proc.new {|record| record.callbacks << 'before'; true}
    Switch.after_turn_on Proc.new {|record| record.callbacks << 'after'; true}
    
    assert @event.fire(@record)
    assert_equal %w(before after), @record.callbacks
  end
  
  def test_should_pass_additional_arguments_to_callbacks
    Switch.before_turn_on Proc.new {|record, value| record.callbacks << "before-#{value}"; true}
    Switch.after_turn_on Proc.new {|record, value| record.callbacks << "after-#{value}"; true}
    
    assert @event.fire(@record, 'light')
    assert_equal %w(before-light after-light), @record.callbacks
  end
  
  def teardown
    Switch.class_eval do
      @before_turn_on_callbacks = nil
      @after_turn_on_callbacks = nil
      @transition_on_turn_on_callbacks = nil
      @transition_bang_on_turn_on_callbacks = nil
    end
  end
end
