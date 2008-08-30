require 'state_machine/machine'

module PluginAWeek #:nodoc:
  # A state machine is a model of behavior composed of states, transitions,
  # and events.  This helper adds support for defining this type of
  # functionality within your ActiveRecord models.
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
      # events and transitions for the state machine.  *Note* that this block will
      # be executed within the context of the state machine.  As a result, you will
      # not be able to access any class methods on the model unless you refer to
      # them directly (i.e. specifying the class name).
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
      #     state_machine :status, :initial => Proc.new {|switch| (8..22).include?(Time.now.hour) ? 'on' : 'off'} do
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
      # particular states.  These states are enumerated in the PluginAWeek::StateMachine::Machine
      # documentation.  Below are examples of defining the various types of callbacks:
      # 
      #   class Switch < ActiveRecord::Base
      #     state_machine do
      #       before_exit :off, :alert_homeowner
      #       before_enter :on, Proc.new {|switch| ...}
      #       before_loopback :on, :display_warning
      #       
      #       after_exit  :off, :on, :play_sound
      #       after_enter :off, :on, :play_sound
      #       after_loopback :on, Proc.new {|switch| ...}
      #       
      #       ...
      #     end
      def state_machine(*args, &block)
        unless included_modules.include?(PluginAWeek::StateMachine::InstanceMethods)
          write_inheritable_attribute :state_machines, {}
          class_inheritable_reader :state_machines
          
          after_create :run_initial_state_machine_actions
          
          include PluginAWeek::StateMachine::InstanceMethods
        end
        
        options = args.extract_options!
        attribute = args.any? ? args.first.to_s : 'state'
        options[:initial] = state_machines[attribute].initial_state_without_processing if !options.include?(:initial) && state_machines[attribute]
        
        # This will create a new machine for subclasses as well so that the owner_class and
        # initial state can be overridden
        machine = state_machines[attribute] = PluginAWeek::StateMachine::Machine.new(self, attribute, options)
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
        
        attribute_keys = (attributes || {}).keys.map!(&:to_s)
        
        # Set the initial value of each state machine as long as the value wasn't
        # included in the attribute hash passed in
        self.class.state_machines.each do |attribute, machine|
          unless attribute_keys.include?(attribute)
            send("#{attribute}=", machine.initial_state(self))
          end
        end
        
        yield self if block_given?
      end
      
      # Records the transition for the record going into its initial state
      def run_initial_state_machine_actions
        # Make sure that these initial actions are only invoked once
        unless @processed_initial_state_machine_actions
          @processed_initial_state_machine_actions = true
          
          self.class.state_machines.each do |attribute, machine|
            callback = "after_enter_#{attribute}_#{self[attribute]}"
            run_callbacks(callback) if self[attribute] && self.class.respond_to?(callback)
          end
        end
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include PluginAWeek::StateMachine
end
