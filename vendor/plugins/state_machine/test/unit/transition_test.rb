require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransitionTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on')
  end
  
  def test_should_have_an_event
    assert_not_nil @transition.event
  end
  
  def test_should_have_options
    assert_not_nil @transition.options
  end
  
  def test_should_match_any_from_state
    assert @transition.matches?('off')
    assert @transition.matches?('on')
  end
  
  def test_should_match_empty_query
    assert @transition.matches?('off', {})
  end
  
  def test_should_match_if_from_state_included
    assert @transition.matches?('off', :from => 'off')
  end
  
  def test_should_not_match_if_from_state_not_included
    assert !@transition.matches?('off', :from => 'on')
  end
  
  def test_should_allow_matching_of_multiple_from_states
    assert @transition.matches?('off', :from => %w(on off))
  end
  
  def test_should_match_if_except_from_state_not_included
    assert @transition.matches?('off', :except_from => 'on')
  end
  
  def test_should_not_match_if_except_from_state_included
    assert !@transition.matches?('off', :except_from => 'off')
  end
  
  def test_should_allow_matching_of_multiple_except_from_states
    assert @transition.matches?('off', :except_from => %w(on maybe))
  end
  
  def test_should_match_if_to_state_included
    assert @transition.matches?('off', :to => 'on')
  end
  
  def test_should_not_match_if_to_state_not_included
    assert !@transition.matches?('off', :to => 'off')
  end
  
  def test_should_allow_matching_of_multiple_to_states
    assert @transition.matches?('off', :to => %w(on off))
  end
  
  def test_should_match_if_except_to_state_not_included
    assert @transition.matches?('off', :except_to => 'off')
  end
  
  def test_should_not_match_if_except_to_state_included
    assert !@transition.matches?('off', :except_to => 'on')
  end
  
  def test_should_allow_matching_of_multiple_except_to_states
    assert @transition.matches?('off', :except_to => %w(off maybe))
  end
  
  def test_should_match_if_on_event_included
    assert @transition.matches?('off', :on => 'turn_on')
  end
  
  def test_should_not_match_if_on_event_not_included
    assert !@transition.matches?('off', :on => 'turn_off')
  end
  
  def test_should_allow_matching_of_multiple_on_events
    assert @transition.matches?('off', :on => %w(turn_off turn_on))
  end
  
  def test_should_match_if_except_on_event_not_included
    assert @transition.matches?('off', :except_on => 'turn_off')
  end
  
  def test_should_not_match_if_except_on_event_included
    assert !@transition.matches?('off', :except_on => 'turn_on')
  end
  
  def test_should_allow_matching_of_multiple_except_on_events
    assert @transition.matches?('off', :except_on => %w(turn_off not_sure))
  end
  
  def test_should_match_if_from_state_and_to_state_match
    assert @transition.matches?('off', :from => 'off', :to => 'on')
  end
  
  def test_should_not_match_if_from_state_matches_but_not_to_state
    assert !@transition.matches?('off', :from => 'off', :to => 'off')
  end
  
  def test_should_not_match_if_to_state_matches_but_not_from_state
    assert !@transition.matches?('off', :from => 'on', :to => 'on')
  end
  
  def test_should_match_if_from_state_to_state_and_on_event_match
    assert @transition.matches?('off', :from => 'off', :to => 'on', :on => 'turn_on')
  end
  
  def test_should_not_match_if_from_state_and_to_state_match_but_not_on_event
    assert !@transition.matches?('off', :from => 'off', :to => 'on', :on => 'turn_off')
  end
  
  def test_should_be_able_to_perform_on_all_states
    record = new_switch(:state => 'off')
    assert @transition.can_perform?(record)
    
    record = new_switch(:state => 'on')
    assert @transition.can_perform?(record)
  end
  
  def test_should_perform_for_all_states
    record = new_switch(:state => 'off')
    assert @transition.perform(record)
    
    record = new_switch(:state => 'on')
    assert @transition.perform(record)
  end
  
  def test_should_not_raise_exception_if_not_valid_during_perform
    record = new_switch(:state => 'off')
    record.fail_validation = true
    
    assert !@transition.perform(record)
  end
  
  def test_should_raise_exception_if_not_valid_during_perform!
    record = new_switch(:state => 'off')
    record.fail_validation = true
    
    assert_raise(ActiveRecord::RecordInvalid) {@transition.perform!(record)}
  end
  
  def test_should_not_raise_exception_if_not_saved_during_perform
    record = new_switch(:state => 'off')
    record.fail_save = true
    
    assert !@transition.perform(record)
  end
  
  def test_should_raise_exception_if_not_saved_during_perform!
    record = new_switch(:state => 'off')
    record.fail_save = true
    
    assert_raise(ActiveRecord::RecordNotSaved) {@transition.perform!(record)}
  end
  
  def test_should_raise_exception_if_invalid_option_specified
    assert_raise(ArgumentError) {PluginAWeek::StateMachine::Transition.new(@event, :invalid => true)}
  end
  
  def test_should_raise_exception_if_to_option_not_specified
    assert_raise(ArgumentError) {PluginAWeek::StateMachine::Transition.new(@event, :from => 'off')}
  end
end

class TransitionWithConditionalTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @switch = create_switch(:state => 'off')
  end
  
  def test_should_be_able_to_perform_if_if_is_true
    transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :if => lambda {true})
    assert transition.can_perform?(@switch)
  end
  
  def test_should_not_be_able_to_perform_if_if_is_false
    transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :if => lambda {false})
    assert !transition.can_perform?(@switch)
  end
  
  def test_should_be_able_to_perform_if_unless_is_false
    transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :unless => lambda {false})
    assert transition.can_perform?(@switch)
  end
  
  def test_should_not_be_able_to_perform_if_unless_is_true
    transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :unless => lambda {true})
    assert !transition.can_perform?(@switch)
  end
  
  def test_should_pass_in_record_as_argument
    transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :if => lambda {|record| !record.nil?})
    assert transition.can_perform?(@switch)
  end
  
  def test_should_be_able_to_perform_if_method_evaluates_to_true
    @switch.data = true
    transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :if => :data)
    assert transition.can_perform?(@switch)
  end
  
  def test_should_not_be_able_to_perform_if_method_evaluates_to_false
    @switch.data = false
    transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :if => :data)
    assert !transition.can_perform?(@switch)
  end
end

class TransitionWithLoopbackTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'on')
  end
  
  def test_should_be_able_to_perform
    record = new_switch(:state => 'on')
    assert @transition.can_perform?(record)
  end
  
  def test_should_perform_for_valid_from_state
    record = new_switch(:state => 'on')
    assert @transition.perform(record)
  end
end

class TransitionWithFromStateTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'off')
  end
  
  def test_should_not_be_able_to_perform_if_record_state_is_not_from_state
    record = new_switch(:state => 'on')
    assert !@transition.can_perform?(record)
  end
  
  def test_should_be_able_to_perform_if_record_state_is_from_state
    record = new_switch(:state => 'off')
    assert @transition.can_perform?(record)
  end
  
  def test_should_perform_for_valid_from_state
    record = new_switch(:state => 'off')
    assert @transition.perform(record)
  end
end

class TransitionWithMultipleFromStatesTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => %w(off on))
  end
  
  def test_should_not_be_able_to_perform_if_record_state_is_not_from_state
    record = new_switch(:state => 'unknown')
    assert !@transition.can_perform?(record)
  end
  
  def test_should_be_able_to_perform_if_record_state_is_any_from_state
    record = new_switch(:state => 'off')
    assert @transition.can_perform?(record)
    
    record = new_switch(:state => 'on')
    assert @transition.can_perform?(record)
  end
  
  def test_should_perform_for_any_valid_from_state
    record = new_switch(:state => 'off')
    assert @transition.perform(record)
    
    record = new_switch(:state => 'on')
    assert @transition.perform(record)
  end
end

class TransitionWithMismatchedFromStatesRequiredTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :except_from => 'on')
  end
  
  def test_should_be_able_to_perform_if_record_state_is_not_from_state
    record = new_switch(:state => 'off')
    assert @transition.can_perform?(record)
  end
  
  def test_should_not_be_able_to_perform_if_record_state_is_from_state
    record = new_switch(:state => 'on')
    assert !@transition.can_perform?(record)
  end
  
  def test_should_perform_for_valid_from_state
    record = new_switch(:state => 'off')
    assert @transition.perform(record)
  end
  
  def test_should_not_perform_for_invalid_from_state
    record = new_switch(:state => 'on')
    assert !@transition.can_perform?(record)
  end
end

class TransitionAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'off')
    
    @record = create_switch(:state => 'off')
    @transition.perform(@record)
    @record.reload
  end
  
  def test_should_update_the_state_to_the_to_state
    assert_equal 'on', @record.state
  end
  
  def test_should_no_longer_be_able_to_perform_on_the_record
    assert !@transition.can_perform?(@record)
  end
end

class TransitionWithLoopbackAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'on')
    
    @record = create_switch(:state => 'on')
    @record.kind = 'light'
    @transition.perform(@record)
    @record.reload
  end
  
  def test_should_have_the_same_attribute
    assert_equal 'on', @record.state
  end
  
  def test_should_save_the_record
    assert_equal 'light', @record.kind
  end
  
  def test_should_still_be_able_to_perform_on_the_record
    assert @transition.can_perform?(@record)
  end
end

class TransitionWithCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'off')
    @record = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_transition_state, :after_transition_state
  end
  
  def test_should_include_record_in_callback
    Switch.before_transition_state lambda {|record| record == @record}
    
    assert @transition.perform(@record)
  end
  
  def test_should_not_perform_if_before_callback_fails
    Switch.before_transition_state lambda {|record| false}
    Switch.after_transition_state lambda {|record| record.callbacks << 'after'; true}
    
    assert !@transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_raise_exception_if_before_callback_fails_during_perform!
    Switch.before_transition_state lambda {|record| false}
    
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@transition.perform!(@record)}
  end
  
  def test_should_perform_if_after_callback_fails
    Switch.before_transition_state lambda {|record| record.callbacks << 'before'; true}
    Switch.after_transition_state lambda {|record| false}
    
    assert @transition.perform(@record)
    assert_equal %w(before), @record.callbacks
  end
  
  def test_should_not_raise_exception_if_after_callback_fails_during_perform!
    Switch.before_transition_state lambda {|record| record.callbacks << 'before'; true}
    Switch.after_transition_state lambda {|record| false}
    
    assert @transition.perform!(@record)
  end
  
  def test_should_perform_if_all_callbacks_are_successful
    Switch.before_transition_state lambda {|record| record.callbacks << 'before'; true}
    Switch.after_transition_state lambda {|record| record.callbacks << 'after'; true}
    
    assert @transition.perform(@record)
    assert_equal %w(before after), @record.callbacks
  end
  
  def test_should_stop_before_callbacks_if_any_fail
    Switch.before_transition_state lambda {|record| false}
    Switch.before_transition_state lambda {|record| record.callbacks << 'before_2'; true}
    
    assert !@transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_stop_after_callbacks_if_any_fail
    Switch.after_transition_state lambda {|record| false}
    Switch.after_transition_state lambda {|record| record.callbacks << 'after_2'; true}
    
    assert @transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def teardown
    Switch.class_eval do
      @before_transition_state_callbacks = nil
      @after_transition_state_callbacks = nil
    end
  end
end

class TransitionWithCallbackConditionalsTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'off')
    @record = create_switch(:state => 'off')
    @invoked = false
    
    Switch.define_callbacks :before_transition_state, :after_transition_state
  end
  
  def test_should_invoke_callback_if_if_is_true
    Switch.before_transition_state lambda {|record| @invoked = true}, :if => lambda {true}
    @transition.perform(@record)
    assert @invoked
  end
  
  def test_should_not_invoke_callback_if_if_is_false
    Switch.before_transition_state lambda {|record| @invoked = true}, :if => lambda {false}
    @transition.perform(@record)
    assert !@invoked
  end
  
  def test_should_invoke_callback_if_unless_is_false
    Switch.before_transition_state lambda {|record| @invoked = true}, :unless => lambda {false}
    @transition.perform(@record)
    assert @invoked
  end
  
  def test_should_not_invoke_callback_if_unless_is_true
    Switch.before_transition_state lambda {|record| @invoked = true}, :unless => lambda {true}
    @transition.perform(@record)
    assert !@invoked
  end
  
  def teardown
    Switch.class_eval do
      @before_transition_state_callbacks = nil
      @after_transition_state_callbacks = nil
    end
  end
end

class TransitionWithCallbackQueryTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'off')
    @record = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_transition_state, :after_transition_state
  end
  
  def test_should_invoke_callback_if_from_state_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :from => 'off'
    @transition.perform(@record)
    assert @invoked
  end
  
  def test_should_not_invoke_callback_if_from_state_not_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :from => 'on'
    @transition.perform(@record)
    assert !@invoked
  end
  
  def test_should_invoke_callback_if_except_from_state_not_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :except_from => 'on'
    @transition.perform(@record)
    assert @invoked
  end
  
  def test_should_not_invoke_callback_if_except_from_state_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :except_from => 'off'
    @transition.perform(@record)
    assert !@invoked
  end
  
  def test_should_invoke_callback_if_to_state_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :to => 'on'
    @transition.perform(@record)
    assert @invoked
  end
  
  def test_should_not_invoke_callback_if_to_state_not_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :to => 'off'
    @transition.perform(@record)
    assert !@invoked
  end
  
  def test_should_invoke_callback_if_except_to_state_not_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :except_to => 'off'
    @transition.perform(@record)
    assert @invoked
  end
  
  def test_should_not_invoke_callback_if_except_to_state_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :except_to => 'on'
    @transition.perform(@record)
    assert !@invoked
  end
  
  def test_should_invoke_callback_if_on_event_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :on => 'turn_on'
    @transition.perform(@record)
    assert @invoked
  end
  
  def test_should_not_invoke_callback_if_on_event_not_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :on => 'turn_off'
    @transition.perform(@record)
    assert !@invoked
  end
  
  def test_should_invoke_callback_if_except_on_event_not_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :except_on => 'turn_off'
    @transition.perform(@record)
    assert @invoked
  end
  
  def test_should_not_invoke_callback_if_except_on_event_included
    Switch.before_transition_state lambda {|record| @invoked = true}, :except_on => 'turn_on'
    @transition.perform(@record)
    assert !@invoked
  end
  
  def test_should_skip_callbacks_that_do_not_match
    Switch.before_transition_state lambda {|record| false}, :from => 'on'
    Switch.before_transition_state lambda {|record| @invoked = true}, :from => 'off'
    @transition.perform(@record)
    assert @invoked
  end
  
  def teardown
    Switch.class_eval do
      @before_transition_state_callbacks = nil
      @after_transition_state_callbacks = nil
    end
  end
end

class TransitionWithObserversTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'off')
    @record = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_transition_state, :after_transition_state
    SwitchObserver.notifications = []
  end
  
  def test_should_notify_all_callbacks_if_successful
    @transition.perform(@record)
    
    expected = [
      ['before_turn_on', @record, 'off', 'on'],
      ['before_transition', @record, 'state', 'turn_on', 'off', 'on'],
      ['after_turn_on', @record, 'off', 'on'],
      ['after_transition', @record, 'state', 'turn_on', 'off', 'on']
    ]
    
    assert_equal expected, SwitchObserver.notifications
  end
  
  def test_should_notify_before_callbacks_if_before_callback_fails
    Switch.before_transition_state lambda {|record| false}
    @transition.perform(@record)
    
    expected = [
      ['before_turn_on', @record, 'off', 'on'],
      ['before_transition', @record, 'state', 'turn_on', 'off', 'on']
    ]
    
    assert_equal expected, SwitchObserver.notifications
  end
  
  def test_should_notify_before_and_after_callbacks_if_after_callback_fails
    Switch.after_transition_state lambda {|record| false}
    @transition.perform(@record)
    
    expected = [
      ['before_turn_on', @record, 'off', 'on'],
      ['before_transition', @record, 'state', 'turn_on', 'off', 'on'],
      ['after_turn_on', @record, 'off', 'on'],
      ['after_transition', @record, 'state', 'turn_on', 'off', 'on']
    ]
    
    assert_equal expected, SwitchObserver.notifications
  end
  
  def teardown
    Switch.class_eval do
      @before_transition_state_callbacks = nil
      @after_transition_state_callbacks = nil
    end
  end
end
