module PluginAWeek #:nodoc:
  module StateMachine
    # An invalid transition was attempted
    class InvalidTransition < StandardError
    end
    
    # A transition represents a state change and is described by a condition
    # that would need to be fulfilled to enable the transition.  Transitions
    # consist of:
    # * An event
    # * One or more starting states
    # * An ending state
    class Transition
      # The event that caused the transition
      attr_reader :event
      
      # The configuration for this transition
      attr_reader :options
      
      delegate  :machine,
                  :to => :event
      
      # Creates a new transition within the context of the given event.
      # 
      # Configuration options:
      # * +to+ - The state being transitioned to
      # * +from+ - One or more states being transitioned from.  Default is nil (can transition from any state)
      # * +except_from+ - One or more states that *can't* be transitioned from.
      # * +if+ - Specifies a method, proc or string to call to determine if the transition should occur (e.g. :if => :moving?, or :if => Proc.new {|car| car.speed > 60}). The method, proc or string should return or evaluate to a true or false value.
      # * +unless+ - Specifies a method, proc or string to call to determine if the transition should not occur (e.g. :unless => :stopped?, or :unless => Proc.new {|car| car.speed <= 60}). The method, proc or string should return or evaluate to a true or false value.
      def initialize(event, options) #:nodoc:
        @event = event
        @options = options
        @options.symbolize_keys!
        
        options.assert_valid_keys(:to, :from, :except_from, :if, :unless)
        raise ArgumentError, ':to state must be specified' unless options.include?(:to)
      end
      
      # Determines whether the given query options match the machine state that
      # this transition describes.  Since transitions have no way of telling
      # what the *current* from state is in this context (may be called before
      # or after a transition has occurred), it must be provided.
      # 
      # Query options:
      # * +to+ - One or more states being transitioned to.  If none are specified, then this will always match.
      # * +from+ - One or more states being transitioned from.  If none are specified, then this will always match.
      # * +on+ - One or more events that fired the transition.  If none are specified, then this will always match.
      # * +except_to+ - One more states *not* being transitioned to
      # * +except_from+ - One or more states *not* being transitioned from
      # * +except_on+ - One or more events that *did not* fire the transition.
      # 
      # *Note* that if the given from state is not an actual valid state for this
      # transition, then an ArgumentError will be raised.
      # 
      # == Examples
      # 
      #   event = PluginAWeek::StateMachine::Event.new(machine, 'ignite')
      #   transition = PluginAWeek::StateMachine::Transition.new(event, :to => 'idling', :from => 'parked')
      #   
      #   # Successful
      #   transition.matches?('parked')                                                       # => true
      #   transition.matches?('parked', :from => 'parked')                                    # => true
      #   transition.matches?('parked', :to => 'idling')                                      # => true
      #   transition.matches?('parked', :on => 'ignite')                                      # => true
      #   transition.matches?('parked', :from => 'parked', :to => 'idling')                   # => true
      #   transition.matches?('parked', :from => 'parked', :to => 'idling', :on => 'ignite')  # => true
      #   
      #   # Unsuccessful
      #   transition.matches?('idling')                                                     # => ArgumentError: "idling" is not a valid from state for transition
      #   transition.matches?('parked', :from => 'idling')                                  # => false
      #   transition.matches?('parked', :to => 'first_gear')                                # => false
      #   transition.matches?('parked', :on => 'park')                                      # => false
      #   transition.matches?('parked', :from => 'parked', :to => 'first_gear')             # => false
      #   transition.matches?('parked', :from => 'parked', :to => 'idling', :on => 'park')  # => false
      def matches?(from_state, query = {})
        raise ArgumentError, "\"#{from_state}\" is not a valid from state for transition" unless valid_from_state?(from_state)
        
        # Ensure that from state, to state, and event match the query
        query.blank? ||
        find_match(from_state, query[:from], query[:except_from]) &&
        find_match(@options[:to], query[:to], query[:except_to]) &&
        find_match(event.name, query[:on], query[:except_on])
      end
      
      # Determines whether this transition can be performed on the given record.
      # This checks two things:
      # 1. Does the from state match what's configured for this transition
      # 2. If so, do the conditional :if/:unless options for the transition
      # allow the transition to be performed?
      # 
      # If both of those two checks pass, then this transition can be performed
      # by subsequently calling +perform+/<tt>perform!</tt>
      def can_perform?(record)
        if valid_from_state?(record.send(machine.attribute))
          # Verify that the conditional evaluates to true for the record
          if @options[:if]
            evaluate_method(@options[:if], record)
          elsif @options[:unless]
            !evaluate_method(@options[:unless], record)
          else
            true
          end
        else
          false
        end
      end
      
      # Runs the actual transition and any before/after callbacks associated
      # with the transition.  Additional arguments are passed to the callbacks.
      # 
      # *Note* that the caller should check <tt>matches?</tt> before being
      # called.  This will *not* check whether transition should be performed.
      def perform(record)
        run(record, false)
      end
      
      # Runs the actual transition and any before/after callbacks associated
      # with the transition.  Additional arguments are passed to the callbacks.
      # 
      # Any errors during validation or saving will be raised.  If any +before+
      # callbacks fail, a PluginAWeek::StateMachine::InvalidTransition error
      # will be raised.
      def perform!(record)
        run(record, true) || raise(PluginAWeek::StateMachine::InvalidTransition, "Could not transition via :#{event.name} from #{record.send(machine.attribute).inspect} to #{@options[:to].inspect}")
      end
      
      private
        # Determines whether the given from state matches what was configured
        # for this transition
        def valid_from_state?(from_state)
          find_match(from_state, @options[:from], @options[:except_from])
        end
        
        # Attempts to find the given value in either a whitelist of values or
        # a blacklist of values.  The whitelist will always be used first if it
        # is specified.  If neither lists are specified, then this will always
        # find a match. 
        def find_match(value, whitelist, blacklist)
          if whitelist
            Array(whitelist).include?(value)
          elsif blacklist
            !Array(blacklist).include?(value)
          else
            true
          end 
        end
        
        # Evaluates a method for conditionally determining whether this
        # transition is allowed to be performed on the given record.  This is
        # copied from ActiveSupport::Calllbacks::Callback since it has not been
        # extracted into a separate, reusable method.
        def evaluate_method(method, record)
          case method
            when Symbol
              record.send(method)
            when String
              eval(method, record.instance_eval {binding})
            when Proc, Method
              method.call(record)
            else
              raise ArgumentError, 'Transition conditionals must be a symbol denoting the method to call, a string to be evaluated, or a block to be invoked'
            end
        end
        
        # Performs the actual transition, invoking before/after callbacks in the
        # process.  If either the before callbacks fail or the actual save fails,
        # then this transition will fail.
        def run(record, bang)
          from_state = record.send(machine.attribute)
          
          # Stop the transition if any before callbacks fail
          return false if invoke_callbacks(record, :before, from_state) == false
          result = update_state(record, bang)
          
          # Always invoke after callbacks regardless of whether the update failed
          invoke_callbacks(record, :after, from_state)
          
          result
        end
        
        # Updates the record's attribute to the state represented by this
        # transition.  Even if the transition is a loopback, the record will
        # still be saved.
        def update_state(record, bang)
          record.send("#{machine.attribute}=", @options[:to])
          bang ? record.save! : record.save
        end
        
        # Runs the callbacks of the given type for this transition
        def invoke_callbacks(record, type, from_state)
          # Transition callback
          kind = "#{type}_transition_#{machine.attribute}"
          
          result = if record.class.respond_to?("#{kind}_callback_chain")
            record.class.send("#{kind}_callback_chain").all? do |callback|
              # false indicates that the remaining callbacks should be skipped
              !matches?(from_state, callback.options) || callback.call(record) != false
            end
          else
            # No callbacks defined for attribute: always successful
            true
          end
          
          # Notify observers
          notify("#{type}_#{event.name}", record, from_state, @options[:to])
          notify("#{type}_transition", record, machine.attribute, event.name, from_state, @options[:to])
          
          result
        end
        
        # Sends a notification to all observers of the record's class
        def notify(method, record, *args)
          # This technique of notifying observers is much less than ideal.
          # Unfortunately, ActiveRecord only allows the record to be passed into
          # Observer methods.  As a result, it's not possible to pass in the
          # from state, to state, and other contextual information for the
          # transition.
          record.class.class_eval do
            @observer_peers.dup.each do |observer|
              observer.send(method, record, *args) if observer.respond_to?(method)
            end if defined?(@observer_peers)
          end
        end
    end
  end
end
