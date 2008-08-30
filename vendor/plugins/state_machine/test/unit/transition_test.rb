require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransitionTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on')
  end
  
  def test_should_not_have_any_from_states
    assert @transition.from_states.empty?
  end
  
  def test_should_not_be_a_loopback_if_from_state_is_different
    assert !@transition.loopback?('off')
  end
  
  def test_should_have_a_to_state
    assert_equal 'on', @transition.to_state
  end
  
  def test_should_be_loopback_if_from_state_is_same
    assert @transition.loopback?('on')
  end
  
  def test_should_be_able_to_perform_on_all_states
    record = new_switch(:state => 'off')
    assert @transition.can_perform_on?(record)
    
    record = new_switch(:state => 'on')
    assert @transition.can_perform_on?(record)
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

class TransitionWithLoopbackTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'on')
  end
  
  def test_should_be_able_to_perform
    record = new_switch(:state => 'on')
    assert @transition.can_perform_on?(record)
  end
  
  def test_should_perform_for_valid_from_state
    record = new_switch(:state => 'on')
    assert @transition.perform(record)
  end
end

class TransitionWithFromStateTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'off')
  end
  
  def test_should_have_a_from_state
    assert_equal ['off'], @transition.from_states
  end
  
  def test_should_not_be_able_to_perform_if_record_state_is_not_from_state
    record = new_switch(:state => 'on')
    assert !@transition.can_perform_on?(record)
  end
  
  def test_should_be_able_to_perform_if_record_state_is_from_state
    record = new_switch(:state => 'off')
    assert @transition.can_perform_on?(record)
  end
  
  def test_should_perform_for_valid_from_state
    record = new_switch(:state => 'off')
    assert @transition.perform(record)
  end
end

class TransitionWithMultipleFromStatesTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => %w(off on))
  end
  
  def test_should_have_multiple_from_states
    assert_equal ['off', 'on'], @transition.from_states
  end
  
  def test_should_not_be_able_to_perform_if_record_state_is_not_from_state
    record = new_switch(:state => 'unknown')
    assert !@transition.can_perform_on?(record)
  end
  
  def test_should_be_able_to_perform_if_record_state_is_any_from_state
    record = new_switch(:state => 'off')
    assert @transition.can_perform_on?(record)
    
    record = new_switch(:state => 'on')
    assert @transition.can_perform_on?(record)
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
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :except_from => 'on')
  end
  
  def test_should_have_a_from_state
    assert_equal ['on'], @transition.from_states
  end
  
  def test_should_be_able_to_perform_if_record_state_is_not_from_state
    record = new_switch(:state => 'off')
    assert @transition.can_perform_on?(record)
  end
  
  def test_should_not_be_able_to_perform_if_record_state_is_from_state
    record = new_switch(:state => 'on')
    assert !@transition.can_perform_on?(record)
  end
  
  def test_should_perform_for_valid_from_state
    record = new_switch(:state => 'off')
    assert @transition.perform(record)
  end
  
  def test_should_not_perform_for_invalid_from_state
    record = new_switch(:state => 'on')
    assert !@transition.can_perform_on?(record)
  end
end

class TransitionAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
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
    assert !@transition.can_perform_on?(@record)
  end
end

class TransitionWithLoopbackAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
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
    assert @transition.can_perform_on?(@record)
  end
end

class TransitionWithCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'off')
    @record = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_exit_state_off, :before_enter_state_on, :before_loopback_state_on, :after_exit_state_off, :after_enter_state_on, :after_loopback_state_on
  end
  
  def test_should_not_perform_if_before_exit_callback_fails
    Switch.before_exit_state_off Proc.new {|record| false}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_raise_exception_if_before_exit_callback_fails_during_perform!
    Switch.before_exit_state_off Proc.new {|record| false}
    
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@transition.perform!(@record)}
  end
  
  def test_should_not_perform_if_before_enter_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| false}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal %w(before_exit), @record.callbacks
  end
  
  def test_should_raise_exception_if_after_enter_callback_fails_during_perform!
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| false}
    
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@transition.perform!(@record)}
  end
  
  def test_should_perform_if_after_exit_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| false}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform(@record)
    assert_equal %w(before_exit before_enter after_enter), @record.callbacks
  end
  
  def test_should_not_raise_exception_if_after_exit_callback_fails_during_perform!
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| false}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform!(@record)
  end
  
  def test_should_perform_if_after_enter_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| false}
    
    assert @transition.perform(@record)
    assert_equal %w(before_exit before_enter after_exit), @record.callbacks
  end
  
  def test_should_not_raise_exception_if_after_enter_callback_fails_during_perform!
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| false}
    
    assert @transition.perform!(@record)
  end
  
  def test_should_perform_if_all_callbacks_are_successful
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.before_loopback_state_on Proc.new {|record| record.callbacks << 'before_loopback'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    Switch.after_loopback_state_on Proc.new {|record| record.callbacks << 'after_loopback'; true}
    
    assert @transition.perform(@record)
    assert_equal %w(before_exit before_enter after_exit after_enter), @record.callbacks
  end
  
  def test_should_stop_before_exit_callbacks_if_any_fail
    Switch.before_exit_state_off Proc.new {|record| false}
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    
    assert !@transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_stop_before_enter_callbacks_if_any_fail
    Switch.before_enter_state_on Proc.new {|record| false}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_stop_after_exit_callbacks_if_any_fail
    Switch.after_exit_state_off Proc.new {|record| false}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    
    assert @transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_stop_after_enter_callbacks_if_any_fail
    Switch.after_enter_state_on Proc.new {|record| false}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def teardown
    Switch.class_eval do
      @before_exit_state_off_callbacks = nil
      @before_enter_state_on_callbacks = nil
      @before_loopback_state_on_callbacks = nil
      @after_exit_state_off_callbacks = nil
      @after_enter_state_on_callbacks = nil
      @after_loopback_state_on_callbacks = nil
    end
  end
end

class TransitionWithoutFromStateAndCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on')
    @record = create_switch(:state => 'off')
    
    Switch.define_callbacks :before_exit_state_off, :before_enter_state_on, :after_exit_state_off, :after_enter_state_on
  end
  
  def test_should_not_perform_if_before_exit_callback_fails
    Switch.before_exit_state_off Proc.new {|record| false}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_not_perform_if_before_enter_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| false}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal %w(before_exit), @record.callbacks
  end
  
  def test_should_perform_if_after_exit_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| false}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform(@record)
    assert_equal %w(before_exit before_enter after_enter), @record.callbacks
  end
  
  def test_should_perform_if_after_enter_callback_fails
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| false}
    
    assert @transition.perform(@record)
    assert_equal %w(before_exit before_enter after_exit), @record.callbacks
  end
  
  def test_should_perform_if_all_callbacks_are_successful
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform(@record)
    assert_equal %w(before_exit before_enter after_exit after_enter), @record.callbacks
  end
  
  def test_should_stop_before_exit_callbacks_if_any_fail
    Switch.before_exit_state_off Proc.new {|record| false}
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    
    assert !@transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_stop_before_enter_callbacks_if_any_fail
    Switch.before_enter_state_on Proc.new {|record| false}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    
    assert !@transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_stop_after_exit_callbacks_if_any_fail
    Switch.after_exit_state_off Proc.new {|record| false}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    
    assert @transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def test_should_stop_after_enter_callbacks_if_any_fail
    Switch.after_enter_state_on Proc.new {|record| false}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    
    assert @transition.perform(@record)
    assert_equal [], @record.callbacks
  end
  
  def teardown
    Switch.class_eval do
      @before_exit_state_off_callbacks = nil
      @before_enter_state_on_callbacks = nil
      @after_exit_state_off_callbacks = nil
      @after_enter_state_on_callbacks = nil
    end
  end
end

class TransitionWithLoopbackAndCallbacksTest < Test::Unit::TestCase
  def setup
    @machine = PluginAWeek::StateMachine::Machine.new(Switch, 'state', :initial => 'off')
    @event = PluginAWeek::StateMachine::Event.new(@machine, 'turn_on')
    @transition = PluginAWeek::StateMachine::Transition.new(@event, :to => 'on', :from => 'on')
    @record = create_switch(:state => 'on')
    
    Switch.define_callbacks :before_exit_state_off, :before_enter_state_on, :before_loopback_state_on, :after_exit_state_off, :after_enter_state_on, :after_loopback_state_on
    Switch.before_exit_state_off Proc.new {|record| record.callbacks << 'before_exit'; true}
    Switch.before_enter_state_on Proc.new {|record| record.callbacks << 'before_enter'; true}
    Switch.before_loopback_state_on Proc.new {|record| record.callbacks << 'before_loopback'; true}
    Switch.after_exit_state_off Proc.new {|record| record.callbacks << 'after_exit'; true}
    Switch.after_enter_state_on Proc.new {|record| record.callbacks << 'after_enter'; true}
    Switch.after_loopback_state_on Proc.new {|record| record.callbacks << 'after_loopback'; true}
    
    assert @transition.perform(@record)
  end
  
  def test_should_not_run_before_exit_callbacks
    assert !@record.callbacks.include?('before_exit')
  end
  
  def test_should_not_run_before_enter_callbacks
    assert !@record.callbacks.include?('before_enter')
  end
  
  def test_should_run_before_loopback_callbacks
    assert @record.callbacks.include?('before_loopback')
  end
  
  def test_should_not_run_after_exit_callbacks
    assert !@record.callbacks.include?('after_exit')
  end
  
  def test_should_not_run_after_enter_callbacks
    assert !@record.callbacks.include?('after_enter')
  end
  
  def test_should_run_after_loopback_callbacks
    assert @record.callbacks.include?('after_loopback')
  end
  
  def teardown
    Switch.class_eval do
      @before_exit_state_off_callbacks = nil
      @before_enter_state_on_callbacks = nil
      @before_loopback_state_on_callbacks = nil
      @after_exit_state_off_callbacks = nil
      @after_enter_state_on_callbacks = nil
      @after_loopback_state_on_callbacks = nil
    end
  end
end
