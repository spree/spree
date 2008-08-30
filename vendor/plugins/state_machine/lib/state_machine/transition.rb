module PluginAWeek #:nodoc:
  module StateMachine
    # An invalid transition was attempted
    class InvalidTransition < StandardError
    end
    
    # A transition indicates a state change and is described by a condition
    # that would need to be fulfilled to enable the transition.  Transitions
    # consist of:
    # * The starting state(s)
    # * The ending state
    # * A guard to check if the transition is allowed
    class Transition
      # The state to which the transition is being made
      attr_reader :to_state
      
      # The states from which the transition can be made
      attr_reader :from_states
      
      # The event that caused the transition
      attr_reader :event
      
      delegate  :machine,
                  :to => :event
      
      # Creates a new transition within the context of the given event.
      # 
      # Configuration options:
      # * +to+ - The state being transitioned to
      # * +from+ - One or more states being transitioned from.  Default is nil (can transition from any state)
      # * +except_from+ - One or more states that *can't* be transitioned from.
      def initialize(event, options) #:nodoc:
        @event = event
        
        options.assert_valid_keys(:to, :from, :except_from)
        raise ArgumentError, ':to state must be specified' unless options.include?(:to)
        
        # Get the states involved in the transition
        @to_state = options[:to]
        @from_states = Array(options[:from] || options[:except_from])
        
        # Should we be matching the from states?
        @require_match = !options[:from].nil?
      end
      
      # Whether or not this is a loopback transition (i.e. from and to state are the same)
      def loopback?(from_state)
        from_state == to_state
      end
      
      # Determines whether or not this transition can be performed on the given
      # record.  The transition can be performed if the record's state matches
      # one of the states that are valid in this transition.
      def can_perform_on?(record)
        from_states.empty? || from_states.include?(record.send(machine.attribute)) == @require_match
      end
      
      # Runs the actual transition and any callbacks associated with entering
      # and exiting the states.  Any additional arguments are passed to the
      # callbacks.
      # 
      # *Note* that the caller should check <tt>can_perform_on?</tt> before calling
      # perform.  This will *not* check whether transition should be performed.
      def perform(record, *args)
        perform_with_optional_bang(record, false, *args)
      end
      
      # Runs the actual transition and any callbacks associated with entering
      # and exiting the states. Any errors during validation or saving will be
      # raised.  If any +before+ callbacks fail, a PluginAWeek::StateMachine::InvalidTransition
      # error will be raised.
      def perform!(record, *args)
        perform_with_optional_bang(record, true, *args) || raise(PluginAWeek::StateMachine::InvalidTransition, "Cannot transition via :#{event.name} from #{record.send(machine.attribute).inspect} to #{to_state.inspect}")
      end
      
      private
        # Performs the transition
        def perform_with_optional_bang(record, bang, *args)
          state = record.send(machine.attribute)
          
          return false if invoke_before_callbacks(state, record) == false
          result = update_state(state, bang, record)
          invoke_after_callbacks(state, record)
          result
        end
        
        # Updates the record's attribute to the state represented by this transition
        # Even if the transition is a loopback, the record will still be saved
        def update_state(from_state, bang, record)
          record.send("#{machine.attribute}=", to_state)
          bang ? record.save! : record.save
        end
        
        def invoke_before_callbacks(from_state, record)
          # Start leaving the last state and start entering the next state
          if loopback?(from_state)
            invoke_callbacks(:before_loopback, from_state, record)
          else
            invoke_callbacks(:before_exit, from_state, record) && invoke_callbacks(:before_enter, to_state, record)
          end
        end
        
        def invoke_after_callbacks(from_state, record)
          # Start leaving the last state and start entering the next state
          if loopback?(from_state)
            invoke_callbacks(:after_loopback, from_state, record)
          else
            invoke_callbacks(:after_exit, from_state, record)
            invoke_callbacks(:after_enter, to_state, record)
          end
          
          true
        end
        
        def invoke_callbacks(type, state, record)
          kind = "#{type}_#{machine.attribute}_#{state}"
          if record.class.respond_to?("#{kind}_callback_chain")
            record.run_callbacks(kind) {|result, record| result == false}
          else
            true
          end
        end
    end
  end
end
