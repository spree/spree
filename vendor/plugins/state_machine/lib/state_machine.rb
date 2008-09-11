require 'state_machine/machine'

module PluginAWeek #:nodoc:
  # A state machine is a model of behavior composed of states, events, and
  # transitions.  This helper adds support for defining this type of
  # functionality within ActiveRecord models.
  module StateMachine
    def self.included(base) #:nodoc:
      base.class_eval do
        extend PluginAWeek::StateMachine::MacroMethods
      end
    end
    
    module MacroMethods
      # Creates a state machine for the given attribute.  The default attribute
      # is "state".
      # 
      # Configuration options:
      # * +initial+ - The initial value of the attribute.  This can either be the actual value or a Proc for dynamic initial states.
      # 
      # This also requires a block which will be used to actually configure the
      # events and transitions for the state machine.  *Note* that this block
      # will be executed within the context of the state machine.  As a result,
      # you will not be able to access any class methods on the model unless you
      # refer to them directly (i.e. specifying the class name).
      # 
      # For examples on the types of configured state machines and blocks, see
      # the section below.
      # 
      # == Examples
      # 
      # With the default attribute and no initial state:
      # 
      #   class Switch < ActiveRecord::Base
      #     state_machine do
      #       event :park do
      #         ...
      #       end
      #     end
      #   end
      # 
      # The above example will define a state machine for the attribute "state"
      # on the model.  Every switch will start with no initial state.
      # 
      # With a custom attribute:
      # 
      #   class Switch < ActiveRecord::Base
      #     state_machine :status do
      #       ...
      #     end
      #   end
      # 
      # With a static initial state:
      # 
      #   class Switch < ActiveRecord::Base
      #     state_machine :status, :initial => 'off' do
      #       ...
      #     end
      #   end
      # 
      # With a dynamic initial state:
      # 
      #   class Switch < ActiveRecord::Base
      #     state_machine :status, :initial => lambda {|switch| (8..22).include?(Time.now.hour) ? 'on' : 'off'} do
      #       ...
      #     end
      #   end
      # 
      # == Events and Transitions
      # 
      # For more information about how to configure an event and its associated
      # transitions, see PluginAWeek::StateMachine::Machine#event
      # 
      # == Defining callbacks
      # 
      # Within the +state_machine+ block, you can also define callbacks for
      # particular states.  For more information about defining these callbacks,
      # see PluginAWeek::StateMachine::Machine#before_transition and
      # PluginAWeek::StateMachine::Machine#after_transition.
      def state_machine(*args, &block)
        unless included_modules.include?(PluginAWeek::StateMachine::InstanceMethods)
          write_inheritable_attribute :state_machines, {}
          class_inheritable_reader :state_machines
          
          include PluginAWeek::StateMachine::InstanceMethods
        end
        
        options = args.extract_options!
        attribute = args.any? ? args.first.to_s : 'state'
        
        # Creates the state machine for this class.  If a superclass has already
        # defined the machine, then a copy of it will be used with its context
        # changed to this class.  If no machine has been defined before for the
        # attribute, a new one will be created.
        original = state_machines[attribute]
        machine = state_machines[attribute] = original ? original.within_context(self, options) : PluginAWeek::StateMachine::Machine.new(self, attribute, options)
        machine.instance_eval(&block) if block
        
        machine
      end
    end
    
    module InstanceMethods
      def self.included(base) #:nodoc:
        base.class_eval do
          alias_method_chain :initialize, :state_machine
        end
      end
      
      # Defines the initial values for state machine attributes
      def initialize_with_state_machine(attributes = nil)
        initialize_without_state_machine(attributes)
        
        # Set the initial value of each state machine as long as the value wasn't
        # included in the initial attributes
        attributes = (attributes || {}).stringify_keys
        self.class.state_machines.each do |attribute, machine|
          send("#{attribute}=", machine.initial_state(self)) unless attributes.include?(attribute)
        end
        
        yield self if block_given?
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include PluginAWeek::StateMachine
end
