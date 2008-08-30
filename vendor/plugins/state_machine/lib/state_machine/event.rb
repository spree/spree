require 'state_machine/transition'

module PluginAWeek #:nodoc:
  module StateMachine
    # An event defines an action that transitions an attribute from one state to
    # another
    class Event
      # The state machine for which this event is defined
      attr_reader :machine
      
      # The name of the action that fires the event
      attr_reader :name
      
      # The list of transitions that can be made for this event
      attr_reader :transitions
      
      delegate  :owner_class,
                  :to => :machine
      
      # Creates a new event within the context of the given machine.
      # 
      # Configuration options:
      # * +before+ - Callbacks to invoke before the event is fired
      # * +after+ - Callbacks to invoke after the event is fired
      def initialize(machine, name, options = {})
        options.assert_valid_keys(:before, :after)
        
        @machine = machine
        @name = name
        @options = options.stringify_keys
        @transitions = []
        
        add_transition_actions
        add_transition_callbacks
        add_event_callbacks
      end
      
      # Creates a new transition to the specified state.
      # 
      # Configuration options:
      # * +to+ - The state that being transitioned to
      # * +from+ - A state or array of states that can be transitioned from. If not specified, then the transition can occur for *any* from state
      # * +except_from+ - A state or array of states that *cannot* be transitioned from.
      # * +if+ - Specifies a method, proc or string to call to determine if the validation should occur (e.g. :if => :moving?, or :if => Proc.new {|car| car.speed > 60}). The method, proc or string should return or evaluate to a true or false value.
      # * +unless+ - Specifies a method, proc or string to call to determine if the transition should not occur (e.g. :unless => :stopped?, or :unless => Proc.new {|car| car.speed <= 60}). The method, proc or string should return or evaluate to a true or false value.
      # 
      # == Examples
      # 
      #   transition :to => 'parked'
      #   transition :to => 'parked', :from => 'first_gear'
      #   transition :to => 'parked', :from => %w(first_gear reverse)
      #   transition :to => 'parked', :from => 'first_gear', :if => :moving?
      #   transition :to => 'parked', :from => 'first_gear', :unless => :stopped?
      #   transition :to => 'parked', :except_from => 'parked'
      def transition(options = {})
        # Slice out the callback options
        options.symbolize_keys!
        callback_options = {:if => options.delete(:if), :unless => options.delete(:unless)}
        
        transition = Transition.new(self, options)
        
        # Add the callback to the model. If the callback fails, then the next
        # available callback for the event will run until one is successful.
        callback = Proc.new {|record, *args| try_transition(transition, false, record, *args)}
        owner_class.send("transition_on_#{name}", callback, callback_options)
        
        # Add the callback! to the model similar to above
        callback = Proc.new {|record, *args| try_transition(transition, true, record, *args)}
        owner_class.send("transition_bang_on_#{name}", callback, callback_options)
        
        transitions << transition
        transition
      end
      
      # Attempts to perform one of the event's transitions for the given record.
      # Any additional arguments will be passed to the event's callbacks.
      def fire(record, *args)
        fire_with_optional_bang(record, false, *args) || false
      end
      
      # Attempts to perform one of the event's transitions for the given record.
      # If the transition cannot be made, then a PluginAWeek::StateMachine::InvalidTransition
      # error will be raised.
      def fire!(record, *args)
        fire_with_optional_bang(record, true, *args) || raise(PluginAWeek::StateMachine::InvalidTransition, "Cannot transition via :#{name} from #{record.send(machine.attribute).inspect}")
      end
      
      private
        # Fires the event
        def fire_with_optional_bang(record, bang, *args)
          record.class.transaction do
            invoke_transition_callbacks(record, bang, *args) || raise(ActiveRecord::Rollback)
          end
        end
        
        # Add the various instance methods that can transition the record using
        # the current event
        def add_transition_actions
          name = self.name
          owner_class = self.owner_class
          machine = self.machine
          
          owner_class.class_eval do
            # Fires the event, returning true/false
            define_method(name) do |*args|
              owner_class.state_machines[machine.attribute].events[name].fire(self, *args)
            end
            
            # Fires the event, raising an exception if it fails
            define_method("#{name}!") do |*args|
              owner_class.state_machines[machine.attribute].events[name].fire!(self, *args)
            end
          end
        end
        
        # Defines callbacks for invoking transitions when this event is performed
        def add_transition_callbacks
          %W(transition transition_bang).each do |callback_name|
            callback_name = "#{callback_name}_on_#{name}"
            owner_class.define_callbacks(callback_name)
          end
        end
        
        # Adds the before/after callbacks for when the event is performed
        def add_event_callbacks
          %w(before after).each do |type|
            callback_name = "#{type}_#{name}"
            owner_class.define_callbacks(callback_name)
            
            # Add each defined callback
            Array(@options[type]).each {|callback| owner_class.send(callback_name, callback)}
          end
        end
        
        # Attempts to perform the given transition. If it can't be performed based
        # on the state of the given record, then the transition will be skipped
        # and the next available one will be tried.
        # 
        # If +bang+ is specified, then perform! will be called on the transition.
        # Otherwise, the default +perform+ will be invoked.
        def try_transition(transition, bang, record, *args)
          if transition.can_perform_on?(record)
            # If the record hasn't been saved yet, then make sure we run any
            # initial actions for the state it's currently in
            record.run_initial_state_machine_actions if record.new_record?
            
            # Now that the state machine has been initialized properly, proceed
            # normally to the callback chain
            return false if invoke_event_callbacks(:before, record, *args) == false
            result = bang ? transition.perform!(record, *args) : transition.perform(record, *args)
            invoke_event_callbacks(:after, record, *args)
            result
          else
            # Indicate that the transition cannot be performed
            :skip
          end
        end
        
        # Invokes a particulary type of callback for the event
        def invoke_event_callbacks(type, record, *args)
          args = [record] + args
          
          record.class.send("#{type}_#{name}_callback_chain").each do |callback|
            result = callback.call(*args)
            break result if result == false
          end
        end
        
        # Invokes the callbacks for each transition in order to find one that
        # completes successfully.
        # 
        # +bang+ indicates whether perform or perform! will be invoked on the
        # transitions in the callback chain
        def invoke_transition_callbacks(record, bang, *args)
          args = [record] + args
          callback_chain = "transition#{'_bang' if bang}_on_#{name}_callback_chain"
          
          result = record.class.send(callback_chain).each do |callback|
            result = callback.call(*args)
            break result if [true, false].include?(result)
          end
          result == true
        end
    end
  end
end
