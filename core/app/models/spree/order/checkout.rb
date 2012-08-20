module Spree
  class Order < ActiveRecord::Base
    module Checkout
      def self.included(klass)
        klass.class_eval do
          cattr_accessor :next_event_transitions
          cattr_accessor :previous_states
          cattr_accessor :checkout_flow
          cattr_accessor :checkout_steps

          def self.checkout_flow(&block)
            if block_given?
              @checkout_flow = block
              define_state_machine!
            else
              @checkout_flow
            end
          end

          def self.define_state_machine!
            self.checkout_steps = []
            @checkout_steps = ActiveSupport::OrderedHash.new
            self.next_event_transitions = []
            self.previous_states = [:cart]
            instance_eval(&checkout_flow)
            klass = self

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
                  order.process_payments!
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
            if options[:if]
              previous_states.each do |state|
                add_transition({:from => state, :to => name}.merge(options))
              end
              self.previous_states << name
            else
              previous_states.each do |state|
                add_transition({:from => state, :to => name}.merge(options))
              end
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
