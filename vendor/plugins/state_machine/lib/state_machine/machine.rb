require 'state_machine/event'

module PluginAWeek #:nodoc:
  module StateMachine
    # Represents a state machine for a particular attribute.  State machines
    # consist of events (a.k.a. actions) and a set of transitions that define
    # how the state changes after a particular event is fired.
    # 
    # A state machine may not necessarily know all of the possible states for
    # an object since they can be any arbitrary value.  As a result, anything
    # that relies on a list of all possible states should keep in mind that if
    # a state has not been referenced *anywhere* in the state machine definition,
    # then it will *not* be a known state.
    # 
    # == Callbacks
    # 
    # Callbacks are supported for hooking before and after every possible
    # transition in the machine.  Each callback is invoked in the order in which
    # it was defined.  See PluginAWeek::StateMachine::Machine#before_transition
    # and PluginAWeek::StateMachine::Machine#after_transition for documentation
    # on how to define new callbacks.
    # 
    # === Cancelling callbacks
    # 
    # If a +before+ callback returns +false+, all the later callbacks and
    # associated transition are cancelled.  If an +after+ callback returns false,
    # the later callbacks are cancelled, but the transition is still successful.
    # This is the same behavior as exposed by ActiveRecord's callback support.
    # 
    # *Note* that if a +before+ callback fails and the bang version of an event
    # was invoked, an exception will be raised instead of returning false.
    # 
    # == Observers
    # 
    # ActiveRecord observers can also hook into state machines in addition to
    # the conventional before_save, after_save, etc. behaviors.  The following
    # types of behaviors can be observed:
    # * events (e.g. before_park/after_park, before_ignite/after_ignite)
    # * transitions (before_transition/after_transition)
    # 
    # Each method takes a set of parameters that provides additional information
    # about the transition that caused the observer to be notified.  Below are
    # examples of defining observers for the following state machine:
    # 
    #   class Vehicle < ActiveRecord::Base
    #     state_machine do
    #       event :park do
    #         transition :to => 'parked', :from => 'idling'
    #       end
    #       ...
    #     end
    #     ...
    #   end
    # 
    # Event behaviors:
    # 
    #   class VehicleObserver < ActiveRecord::Observer
    #     def before_park(vehicle, from_state, to_state)
    #       logger.info "Vehicle #{vehicle.id} instructed to park... state is: #{from_state}, state will be: #{to_state}"
    #     end
    #     
    #     def after_park(vehicle, from_state, to_state)
    #       logger.info "Vehicle #{vehicle.id} instructed to park... state was: #{from_state}, state is: #{to_state}"
    #     end
    #   end
    # 
    # Transition behaviors:
    # 
    #   class VehicleObserver < ActiveRecord::Observer
    #     def before_transition(vehicle, attribute, event, from_state, to_state)
    #       logger.info "Vehicle #{vehicle.id} instructed to #{event}... #{attribute} is: #{from_state}, #{attribute} will be: #{to_state}"
    #     end
    #     
    #     def after_transition(vehicle, attribute, event, from_state, to_state)
    #       logger.info "Vehicle #{vehicle.id} instructed to #{event}... #{attribute} was: #{from_state}, #{attribute} is: #{to_state}"
    #     end
    #   end
    # 
    # One common callback is to record transitions for all models in the system
    # for audit/debugging purposes.  Below is an example of an observer that can
    # easily automate this process for all models:
    # 
    #   class StateMachineObserver < ActiveRecord::Observer
    #     observe Vehicle, Switch, AutoShop
    #     
    #     def before_transition(record, attribute, event, from_state, to_state)
    #       transition = StateTransition.build(:record => record, :attribute => attribute, :event => event, :from_state => from_state, :to_state => to_state)
    #       transition.save # Will cancel rollback/cancel transition if this fails
    #     end
    #   end
    class Machine
      # The class that the machine is defined for
      attr_reader :owner_class
      
      # The attribute for which the state machine is being defined
      attr_reader :attribute
      
      # The initial state that the machine will be in when a record is created
      attr_reader :initial_state
      
      # A list of the states defined in the transitions of all of the events
      attr_reader :states
      
      # The events that trigger transitions
      attr_reader :events
      
      # Creates a new state machine for the given attribute
      # 
      # Configuration options:
      # * +initial+ - The initial value to set the attribute to. This can be an actual value or a proc, which will be evaluated at runtime.
      # 
      # == Scopes
      # 
      # This will automatically create a named scope called with_#{attribute}
      # that will find all records that have the attribute set to a given value.
      # For example,
      # 
      #   Switch.with_state('on') # => Finds all switches where the state is on
      #   Switch.with_states('on', 'off') # => Finds all switches where the state is either on or off
      # 
      # *Note* that if class methods already exist with those names (i.e. "with_state"
      # or "with_states"), then a scope will not be defined for that name.
      def initialize(owner_class, attribute = 'state', options = {})
        set_context(owner_class, options)
        
        @attribute = attribute.to_s
        @states = []
        @events = {}
        
        add_transition_callbacks
        add_named_scopes
      end
      
      # Creates a copy of this machine in addition to copies of each associated
      # event, so that the list of transitions for each event don't conflict
      # with different machines
      def initialize_copy(orig) #:nodoc:
        super
        
        @states = @states.dup
        @events = @events.inject({}) do |events, (name, event)|
          event = event.dup
          event.machine = self
          events[name] = event
          events
        end
      end
      
      # Creates a copy of this machine within the context of the given class.
      # This should be used for inheritance support of state machines.
      def within_context(owner_class, options = {}) #:nodoc:
        machine = dup
        machine.set_context(owner_class, options)
        machine
      end
      
      # Changes the context of this machine to the given class so that new
      # events and transitions are created in the proper context.
      def set_context(owner_class, options = {}) #:nodoc:
        options.assert_valid_keys(:initial)
        
        @owner_class = owner_class
        @initial_state = options[:initial] if options[:initial]
      end
      
      # Gets the initial state of the machine for the given record. If a record
      # is specified a and a dynamic initial state was configured for the machine,
      # then that record will be passed into the proc to help determine the actual
      # value of the initial state.
      # 
      # == Examples
      # 
      # With normal initial state:
      # 
      #   class Vehicle < ActiveRecord::Base
      #     state_machine :initial => 'parked' do
      #       ...
      #     end
      #   end
      #   
      #   Vehicle.state_machines['state'].initial_state(@vehicle)   # => "parked"
      # 
      # With dynamic initial state:
      # 
      #   class Vehicle < ActiveRecord::Base
      #     state_machine :initial => lambda {|vehicle| vehicle.force_idle ? 'idling' : 'parked'} do
      #       ...
      #     end
      #   end
      #   
      #   Vehicle.state_machines['state'].initial_state(@vehicle)   # => "idling"
      def initial_state(record)
        @initial_state.is_a?(Proc) ? @initial_state.call(record) : @initial_state
      end
      
      # Defines an event of the system
      # 
      # == Instance methods
      # 
      # The following instance methods are generated when a new event is defined
      # (the "park" event is used as an example):
      # * <tt>park</tt> - Fires the "park" event, transitioning from the current state to the next valid state.
      # * <tt>park!</tt> - Fires the "park" event, transitioning from the current state to the next valid state.  If the transition cannot happen (for validation, database, etc. reasons), then an error will be raised.
      # * <tt>can_park?</tt> - Checks whether the "park" event can be fired given the current state of the record.
      # 
      # == Defining transitions
      # 
      # +event+ requires a block which allows you to define the possible
      # transitions that can happen as a result of that event.  For example,
      # 
      #   event :park do
      #     transition :to => 'parked', :from => 'idle'
      #   end
      #   
      #   event :first_gear do
      #     transition :to => 'first_gear', :from => 'parked', :if => :seatbelt_on?
      #   end
      # 
      # See PluginAWeek::StateMachine::Event#transition for more information on
      # the possible options that can be passed in.
      # 
      # *Note* that this block is executed within the context of the actual event
      # object.  As a result, you will not be able to reference any class methods
      # on the model without referencing the class itself.  For example,
      # 
      #   class Car < ActiveRecord::Base
      #     def self.safe_states
      #       %w(parked idling stalled)
      #     end
      #     
      #     state_machine :state do
      #       event :park do
      #         transition :to => 'parked', :from => Car.safe_states
      #       end
      #     end
      #   end 
      # 
      # == Example
      # 
      #   class Car < ActiveRecord::Base
      #     state_machine(:state, :initial => 'parked') do
      #       event :park, :after => :release_seatbelt do
      #         transition :to => 'parked', :from => %w(first_gear reverse)
      #       end
      #       ...
      #     end
      #   end
      def event(name, &block)
        name = name.to_s
        event = events[name] ||= Event.new(self, name)
        event.instance_eval(&block)
        
        # Record the states so that the machine can keep a list of all known
        # states that have been defined
        event.transitions.each do |transition|
          @states |= [transition.options[:to]] + Array(transition.options[:from]) + Array(transition.options[:except_from])
          @states.sort!
        end
        
        event
      end
      
      # Creates a callback that will be invoked *before* a transition has been
      # performed, so long as the given configuration options match the transition.
      # Each part of the transition (to state, from state, and event) must match
      # in order for the callback to get invoked.
      # 
      # Configuration options:
      # * +to+ - One or more states being transitioned to.  If none are specified, then all states will match.
      # * +from+ - One or more states being transitioned from.  If none are specified, then all states will match.
      # * +on+ - One or more events that fired the transition.  If none are specified, then all events will match.
      # * +except_to+ - One more states *not* being transitioned to
      # * +except_from+ - One or more states *not* being transitioned from
      # * +except_on+ - One or more events that *did not* fire the transition
      # * +do+ - The callback to invoke when a transition matches. This can be a method, proc or string.
      # * +if+ - A method, proc or string to call to determine if the callback should occur (e.g. :if => :allow_callbacks, or :if => lambda {|user| user.signup_step > 2}). The method, proc or string should return or evaluate to a true or false value. 
      # * +unless+ - A method, proc or string to call to determine if the callback should not occur (e.g. :unless => :skip_callbacks, or :unless => lambda {|user| user.signup_step <= 2}). The method, proc or string should return or evaluate to a true or false value. 
      # 
      # The +except+ group of options (+except_to+, +exception_from+, and
      # +except_on+) acts as the +unless+ equivalent of their counterparts (+to+,
      # +from+, and +on+, respectively)
      # 
      # == The callback
      # 
      # When defining additional configuration options, callbacks must be defined
      # in the :do option like so:
      # 
      #   class Vehicle < ActiveRecord::Base
      #     state_machine do
      #       before_transition :to => 'parked', :do => :set_alarm
      #       ...
      #     end
      #   end
      # 
      # == Examples
      # 
      # Below is an example of a model with one state machine and various types
      # of +before+ transitions defined for it:
      # 
      #   class Vehicle < ActiveRecord::Base
      #     state_machine do
      #       # Before all transitions
      #       before_transition :update_dashboard
      #       
      #       # Before specific transition:
      #       before_transition :to => 'parked', :from => %w(first_gear idling), :on => 'park', :do => :take_off_seatbelt
      #       
      #       # With conditional callback:
      #       before_transition :to => 'parked', :do => :take_off_seatbelt, :if => :seatbelt_on?
      #       
      #       # Using :except counterparts:
      #       before_transition :except_to => 'stalled', :except_from => 'stalled', :except_on => 'crash', :do => :update_dashboard
      #       ...
      #     end
      #   end
      # 
      # As can be seen, any number of transitions can be created using various
      # combinations of configuration options.
      def before_transition(options = {})
        add_transition_callback(:before, options)
      end
      
      # Creates a callback that will be invoked *after* a transition has been
      # performed, so long as the given configuration options match the transition.
      # Each part of the transition (to state, from state, and event) must match
      # in order for the callback to get invoked.
      # 
      # Configuration options:
      # * +to+ - One or more states being transitioned to.  If none are specified, then all states will match.
      # * +from+ - One or more states being transitioned from.  If none are specified, then all states will match.
      # * +on+ - One or more events that fired the transition.  If none are specified, then all events will match.
      # * +except_to+ - One more states *not* being transitioned to
      # * +except_from+ - One or more states *not* being transitioned from
      # * +except_on+ - One or more events that *did not* fire the transition
      # * +do+ - The callback to invoke when a transition matches. This can be a method, proc or string.
      # * +if+ - A method, proc or string to call to determine if the callback should occur (e.g. :if => :allow_callbacks, or :if => lambda {|user| user.signup_step > 2}). The method, proc or string should return or evaluate to a true or false value. 
      # * +unless+ - A method, proc or string to call to determine if the callback should not occur (e.g. :unless => :skip_callbacks, or :unless => lambda {|user| user.signup_step <= 2}). The method, proc or string should return or evaluate to a true or false value. 
      # 
      # The +except+ group of options (+except_to+, +exception_from+, and
      # +except_on+) acts as the +unless+ equivalent of their counterparts (+to+,
      # +from+, and +on+, respectively)
      # 
      # == The callback
      # 
      # When defining additional configuration options, callbacks must be defined
      # in the :do option like so:
      # 
      #   class Vehicle < ActiveRecord::Base
      #     state_machine do
      #       after_transition :to => 'parked', :do => :set_alarm
      #       ...
      #     end
      #   end
      # 
      # == Examples
      # 
      # Below is an example of a model with one state machine and various types
      # of +after+ transitions defined for it:
      # 
      #   class Vehicle < ActiveRecord::Base
      #     state_machine do
      #       # After all transitions
      #       after_transition :update_dashboard
      #       
      #       # After specific transition:
      #       after_transition :to => 'parked', :from => %w(first_gear idling), :on => 'park', :do => :take_off_seatbelt
      #       
      #       # With conditional callback:
      #       after_transition :to => 'parked', :do => :take_off_seatbelt, :if => :seatbelt_on?
      #       
      #       # Using :except counterparts:
      #       after_transition :except_to => 'stalled', :except_from => 'stalled', :except_on => 'crash', :do => :update_dashboard
      #       ...
      #     end
      #   end
      # 
      # As can be seen, any number of transitions can be created using various
      # combinations of configuration options.
      def after_transition(options = {})
        add_transition_callback(:after, options)
      end
      
      private
        # Adds the given callback to the callback chain during a state transition
        def add_transition_callback(type, options)
          options = {:do => options} unless options.is_a?(Hash)
          options.assert_valid_keys(:to, :from, :on, :except_to, :except_from, :except_on, :do, :if, :unless)
          
          # The actual callback (defined in the :do option) must be defined
          raise ArgumentError, ':do callback must be specified' unless options[:do]
          
          # Create the callback
          owner_class.send("#{type}_transition_#{attribute}", options.delete(:do), options)
        end
        
        # Add before/after callbacks for when the attribute transitions to a
        # different value
        def add_transition_callbacks
          %w(before after).each {|type| owner_class.define_callbacks("#{type}_transition_#{attribute}") }
        end
        
        # Add named scopes for finding records with a particular value or values
        # for the attribute
        def add_named_scopes
          [attribute, attribute.pluralize].uniq.each do |name|
            name = "with_#{name}"
            owner_class.named_scope name.to_sym, lambda {|*values| {:conditions => {attribute => values.flatten}}} unless owner_class.respond_to?(name)
          end
        end
    end
  end
end
