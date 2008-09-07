require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EventTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    
    @switch = new_switch
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
    assert @switch.respond_to?(:turn_on)
  end
  
  def test_should_define_an_event_bang_action_on_the_owner_class
    assert @switch.respond_to?(:turn_on!)
  end
  
  def test_should_define_an_event_predicate_on_the_owner_class
    assert @switch.respond_to?(:can_turn_on?)
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {PluginAWeek::StateMachine::Event.new(@machine, 'turn_on', :invalid => true)}
  end
end

class EventDefiningTransitionsTest < Test::Unit::TestCase
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
  
  def test_should_allow_transitioning_without_a_from_state
    assert @event.transition(:to => 'on')
  end
  
  def test_should_allow_transitioning_from_a_single_state
    assert @event.transition(:to => 'on', :from => 'off')
  end
  
  def test_should_allow_transitioning_from_multiple_states
    assert @event.transition(:to => 'on', :from => %w(off on))
  end
  
  def test_should_have_transitions
    transition = @event.transition(:to => 'on')
    assert_equal [transition], @event.transitions
  end
end

class EventAfterBeingCopiedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @copied_event = @event.dup
  end
  
  def test_should_not_have_the_same_collection_of_transitions
    assert_not_same @copied_event.transitions, @event.transitions
  end
end

class EventWithoutTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @switch = create_switch(:state => 'off')
  end
  
  def test_should_not_be_able_to_fire
    assert !@event.can_fire?(@switch)
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

class EventWithTransitionsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition :to => 'error', :from => 'on'
    @switch = create_switch(:state => 'off')
  end
  
  def test_should_not_be_able_to_fire_if_no_transitions_are_matched
    assert !@event.can_fire?(@switch)
  end
  
  def test_should_not_fire_if_no_transitions_are_matched
    assert !@event.fire(@switch)
    assert_equal 'off', @switch.state
  end
  
  def test_should_raise_exception_if_no_transitions_are_matched_during_fire!
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@event.fire!(@switch)}
    assert_equal 'off', @switch.state
  end
  
  def test_should_be_able_to_fire_if_transition_is_matched
    @event.transition :to => 'on'
    assert @event.can_fire?(@switch)
  end
  
  def test_should_fire_if_transition_is_matched
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
end

class EventWithinTransactionTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @event.transition :to => 'on', :from => 'off'
    @switch = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_transition_state
  end
  
  def test_should_save_all_records_within_transaction_if_performed
    Switch.before_transition_state lambda {|record| Switch.create(:state => 'pending'); true}, :from => 'off'
    assert @event.fire(@switch)
    assert_equal 'on', @switch.state
    assert_equal 'pending', Switch.find(:all).last.state
  end
  
  uses_transaction :test_should_rollback_all_records_within_transaction_if_not_performed
  def test_should_rollback_all_records_within_transaction_if_not_performed
    Switch.before_transition_state lambda {|record| Switch.create(:state => 'pending'); false}, :from => 'off'
    assert !@event.fire(@switch)
    assert_equal 1, Switch.count
  ensure
    Switch.destroy_all
  end
  
  uses_transaction :test_should_rollback_all_records_within_transaction_if_not_performed!
  def test_should_rollback_all_records_within_transaction_if_not_performed!
    Switch.before_transition_state lambda {|record| Switch.create(:state => 'pending'); false}, :from => 'off'
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@event.fire!(@switch)}
    assert_equal 1, Switch.count
  ensure
    Switch.destroy_all
  end
  
  def teardown
    Switch.class_eval do
      @before_transition_state_callbacks = nil
    end
  end
end
