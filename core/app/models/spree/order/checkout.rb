module Spree
  class Order < ActiveRecord::Base
    module Checkout
      def self.included(klass)
        klass.class_eval do
          class_attribute :next_event_transitions
          class_attribute :previous_states
          class_attribute :checkout_flow
          class_attribute :checkout_steps

          def self.checkout_flow(&block)
            if block_given?
              @checkout_flow = block
              define_state_machine!
            else
              @checkout_flow
            end
          end

          def self.define_state_machine!
            # Needs to be an ordered hash to preserve flow order
            self.checkout_steps = ActiveSupport::OrderedHash.new
            self.next_event_transitions = []
            self.previous_states = [:cart]

            # Build the checkout flow using the checkout_flow defined either
            # within the Order class, or a decorator for that class.
            #
            # This method may be called multiple times depending on if the
            # checkout_flow is re-defined in a decorator or not.
            instance_eval(&checkout_flow)

            klass = self

            # To avoid a ton of warnings when the state machine is re-defined
            StateMachine::Machine.ignore_method_conflicts = true
            # To avoid multiple occurrences of the same transition being defined
            # On first definition, state_machines will not be defined
            state_machines.clear if respond_to?(:state_machines)
            state_machine :state, :initial => :cart do
              klass.next_event_transitions.each { |t| transition(t.merge(:on => :next)) }

              # Persist the state on the order
              after_transition do |order|
                order.state = order.state
                order.save
              end

              event :cancel do
                transition :to => :canceled, :if => :allow_cancel?
              end

              event :return do
                transition :to => :returned, :from => :awaiting_return
              end

              event :resume do
                transition :to => :resumed, :from => :canceled, :if => :allow_resume?
              end

              event :authorize_return do
                transition :to => :awaiting_return
              end

              before_transition :to => :complete do |order|
                begin
                  order.process_payments! if order.payemnt_required?
                rescue Spree::Core::GatewayError
                  !!Spree::Config[:allow_checkout_on_gateway_error]
                end
              end

              before_transition :to => :delivery, :do => :remove_invalid_shipments!

              after_transition :to => :complete, :do => :finalize!
              after_transition :to => :delivery, :do => :create_tax_charge!
              after_transition :to => :resumed,  :do => :after_resume
              after_transition :to => :canceled, :do => :after_cancel

              after_transition :from => :delivery,  :do => :create_shipment!
            end
          end

          def self.go_to_state(name, options={})
            self.checkout_steps[name] = options
            previous_states.each do |state|
              add_transition({:from => state, :to => name}.merge(options))
            end
            if options[:if]
              self.previous_states << name
            else
              self.previous_states = [name]
            end
          end

          def self.remove_transition(options={})
            if transition = find_transition(options)
              self.next_event_transitions.delete(transition)
            end
          end

          def self.find_transition(options={})
            self.next_event_transitions.detect do |transition|
              transition[options[:from].to_sym] == options[:to].to_sym
            end
          end

          def self.next_event_transitions
            @next_event_transitions ||= []
          end

          def self.checkout_steps
            @checkout_steps ||= ActiveSupport::OrderedHash.new
          end

          def self.add_transition(options)
            self.next_event_transitions << { options.delete(:from) => options.delete(:to) }.merge(options)
          end

          def checkout_steps
            checkout_steps = []
            # TODO: replace this with each_with_object once Ruby 1.9 is standard
            self.class.checkout_steps.each do |step, options|
              if options[:if]
                next unless options[:if].call(self)
              end
              checkout_steps << step
            end
            checkout_steps.map(&:to_s)
          end
        end
      end
    end
  end
end
