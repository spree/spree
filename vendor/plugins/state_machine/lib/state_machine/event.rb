require 'state_machine/transition'

module PluginAWeek #:nodoc:
  module StateMachine
    # An event defines an action that transitions an attribute from one state to
    # another
    class Event
      # The state machine for which this event is defined
      attr_accessor :machine
      
      # The name of the action that fires the event
      attr_reader :name
      
      # The list of transitions that can be made for this event
      attr_reader :transitions
      
      delegate  :owner_class,
                  :to => :machine
      
      # Creates a new event within the context of the given machine
      def initialize(machine, name)
        @machine = machine
        @name = name
        @transitions = []
        
        add_actions
      end
      
      # Creates a copy of this event in addition to the list of associated
      # transitions to prevent conflicts across different events.
      def initialize_copy(orig) #:nodoc:
        super
        @transitions = @transitions.dup
      end
      
      # Creates a new transition to the specified state.
      # 
      # Configuration options:
      # * +to+ - The state that being transitioned to
      # * +from+ - A state or array of states that can be transitioned from. If not specified, then the transition can occur for *any* from state
      # * +except_from+ - A state or array of states that *cannot* be transitioned from.
      # * +if+ - Specifies a method, proc or string to call to determine if the transition should occur (e.g. :if => :moving?, or :if => Proc.new {|car| car.speed > 60}). The method, proc or string should return or evaluate to a true or false value.
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
      def transition(options)
        transitions << transition = Transition.new(self, options)
        transition
      end
      
      # Determines whether any transitions can be performed for this event based
      # on the current state of the given record.
      # 
      # If the event can't be fired, then this will return false, otherwise true.
      def can_fire?(record)
        transitions.any? {|transition| transition.can_perform?(record)}
      end
      
      # Attempts to perform one of the event's transitions for the given record.
      # Any additional arguments will be passed to the event's callbacks.
      def fire(record)
        run(record, false) || false
      end
      
      # Attempts to perform one of the event's transitions for the given record.
      # If the transition cannot be made, then a PluginAWeek::StateMachine::InvalidTransition
      # error will be raised.
      def fire!(record)
        run(record, true) || raise(PluginAWeek::StateMachine::InvalidTransition, "Cannot transition via :#{name} from \"#{record.send(machine.attribute)}\"")
      end
      
      private
        # Add the various instance methods that can transition the record using
        # the current event
        def add_actions
          attribute = machine.attribute
          name = self.name
          
          owner_class.class_eval do
            define_method(name) {self.class.state_machines[attribute].events[name].fire(self)}
            define_method("#{name}!") {self.class.state_machines[attribute].events[name].fire!(self)}
            define_method("can_#{name}?") {self.class.state_machines[attribute].events[name].can_fire?(self)}
          end
        end
        
        # Attempts to find a transition that can be performed for this event.
        # 
        # +bang+ indicates whether +perform+ or <tt>perform!</tt> will be
        # invoked on transitions.
        def run(record, bang)
          result = false
          
          record.class.transaction do
            transitions.each do |transition|
              if transition.can_perform?(record)
                result = bang ? transition.perform!(record) : transition.perform(record)
                break
              end
            end
            
            # Rollback any changes if the transition failed
            raise ActiveRecord::Rollback unless result
          end
          
          result
        end
    end
  end
end
