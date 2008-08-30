require 'state_machine/event'

module PluginAWeek #:nodoc:
  module StateMachine
    # Represents a state machine for a particular attribute.  State machines
    # consist of events (a.k.a. actions) and a set of transitions that define
    # how the state changes after a particular event is fired.
    # 
    # A state machine may not necessarily know all of the possible states for
    # an object since they can be any arbitrary value.
    # 
    # == Callbacks
    # 
    # Callbacks are supported for hooking into event calls and state transitions.
    # The order in which these callbacks are invoked is shown below:
    # * (1) before_exit (from state)
    # * (2) before_enter (to state)
    # * (3) before (event)
    # * (-) update state
    # * (4) after_exit (from state)
    # * (5) after_enter (to state)
    # * (6) after (event)
    # 
    # If the event causes a loopback (i.e. to and from state are the same), then
    # the callback chain is slightly different:
    # 
    # * (1) before_loopback (to/from state)
    # * (2) before (event)
    # * (-) update state
    # * (3) after_loopback (to/from state)
    # * (4) after (event)
    # 
    # One last *important* note about callbacks is that the after_enter callback
    # will be invoked for the initial state when a record is saved (assuming that
    # the initial state is set).  So if an event is fired on an unsaved record,
    # the callback order will be:
    # 
    # * (1) after_enter (initial state)
    # * (2) before_exit (from/initial state)
    # * (3) before_enter (to state)
    # * (4) before (event)
    # * (-) update state
    # * (5) after_exit (from/initial state)
    # * (6) after_enter (to state)
    # * (7) after (event)
    # 
    # == Cancelling callbacks
    # 
    # If a <tt>before_*</tt> callback returns +false+, all the later callbacks
    # and associated event are cancelled.  If an <tt>after_*</tt> callback returns
    # false, all the later callbacks are cancelled.  Callbacks are run in the
    # order in which they are defined.
    # 
    # Note that if a <tt>before_*</tt> callback fails and the bang version of an
    # event was invoked, an exception will be raised instaed of returning false.
    class Machine
      # The events that trigger transitions
      attr_reader :events
      
      # A list of the states defined in the transitions of all of the events
      attr_reader :states
      
      # The attribute for which the state machine is being defined
      attr_accessor :attribute
      
      # The initial state that the machine will be in
      attr_reader :initial_state
      
      # The class that the attribute belongs to
      attr_reader :owner_class
      
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
      def initialize(owner_class, attribute = 'state', options = {})
        options.assert_valid_keys(:initial)
        
        @owner_class = owner_class
        @attribute = attribute.to_s
        @initial_state = options[:initial]
        @events = {}
        @states = []
        
        add_named_scopes
      end
      
      # Gets the initial state of the machine for the given record. The record
      # is only used if a dynamic initial state was configured.
      def initial_state(record)
        @initial_state.is_a?(Proc) ? @initial_state.call(record) : @initial_state
      end
      
      # Gets the initial state without processing it against a particular record
      def initial_state_without_processing
        @initial_state
      end
      
      # Defines an event of the system.  This can take an optional hash that
      # defines callbacks which will be invoked before and after the event is
      # invoked on the object.
      # 
      # Configuration options:
      # * +before+ - One or more callbacks that will be invoked before the event has been fired
      # * +after+ - One or more callbacks that will be invoked after the event has been fired
      # 
      # == Instance methods
      # 
      # The following instance methods are generated when a new event is defined
      # (the "park" event is used as an example):
      # * <tt>park(*args)</tt> - Fires the "park" event, transitioning from the current state to the next valid state.  This takes an optional list of arguments which are passed to the event callbacks.
      # * <tt>park!(*args)</tt> - Fires the "park" event, transitioning from the current state to the next valid state.  This takes an optional list of arguments which are passed to the event callbacks.  If the transition cannot happen (for validation, database, etc. reasons), then an error will be raised
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
      #       %w(parked idling first_gear)
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
      def event(name, options = {}, &block)
        name = name.to_s
        event = events[name] = Event.new(self, name, options)
        event.instance_eval(&block)
        
        # Record the states
        event.transitions.each do |transition|
          @states |= ([transition.to_state] + transition.from_states)
        end
        
        event
      end
      
      # Define state callbacks
      %w(before_exit before_enter before_loopback after_exit after_enter after_loopback).each do |callback_type|
        define_method(callback_type) {|state, callback| add_callback(callback_type, state, callback)}
      end
      
      private
        # Adds the given callback to the callback chain during a state transition
        def add_callback(type, state, callback)
          callback_name = "#{type}_#{attribute}_#{state}"
          owner_class.define_callbacks(callback_name)
          owner_class.send(callback_name, callback)
        end
        
        # Add named scopes for finding records with a particular value or values
        # for the attribute
        def add_named_scopes
          [attribute, attribute.pluralize].each do |name|
            unless owner_class.respond_to?("with_#{name}")
              name = "with_#{name}"
              owner_class.named_scope name.to_sym, Proc.new {|*values| {:conditions => {attribute => values.flatten}}}
            end
          end
        end
    end
  end
end
