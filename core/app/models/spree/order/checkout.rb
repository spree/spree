module Spree
  class Order < Spree::Base
    module Checkout
      def self.included(klass)
        klass.class_eval do
          class_attribute :next_event_transitions
          class_attribute :previous_states
          class_attribute :checkout_flow
          class_attribute :checkout_steps
          class_attribute :removed_transitions

          def self.checkout_flow(&block)
            if block_given?
              @checkout_flow = block
              # define_state_machine!
            else
              @checkout_flow
            end
          end

          def self.go_to_state(name, options={})
            self.checkout_steps[name] = options
            previous_states.each do |state|
              add_transition({from: state, to: name}.merge(options))
            end
            if options[:if]
              self.previous_states << name
            else
              self.previous_states = [name]
            end
          end

          def self.insert_checkout_step(name, options = {})
            before = options.delete(:before)
            after = options.delete(:after) unless before
            after = self.checkout_steps.keys.last unless before || after

            cloned_steps = self.checkout_steps.clone
            cloned_removed_transitions = self.removed_transitions.clone
            self.checkout_flow do
              cloned_steps.each_pair do |key, value|
                self.go_to_state(name, options) if key == before
                self.go_to_state(key, value)
                self.go_to_state(name, options) if key == after
              end
              cloned_removed_transitions.each do |transition|
                self.remove_transition(transition)
              end
            end
          end

          def self.remove_checkout_step(name)
            cloned_steps = self.checkout_steps.clone
            cloned_removed_transitions = self.removed_transitions.clone
            self.checkout_flow do
              cloned_steps.each_pair do |key, value|
                self.go_to_state(key, value) unless key == name
              end
              cloned_removed_transitions.each do |transition|
                self.remove_transition(transition)
              end
            end
          end

          def self.remove_transition(options={})
            self.removed_transitions << options
            self.next_event_transitions.delete(find_transition(options))
          end

          def self.find_transition(options={})
            return nil if options.nil? || !options.include?(:from) || !options.include?(:to)
            self.next_event_transitions.detect do |transition|
              transition[options[:from].to_sym] == options[:to].to_sym
            end
          end

          def self.next_event_transitions
            @next_event_transitions ||= []
          end

          def self.checkout_steps
            @checkout_steps ||= {}
          end

          def self.checkout_step_names
            self.checkout_steps.keys
          end

          def self.add_transition(options)
            self.next_event_transitions << { options.delete(:from) => options.delete(:to) }.merge(options)
          end

          def checkout_steps
            steps = self.class.checkout_steps.each_with_object([]) { |(step, options), checkout_steps|
              next if options.include?(:if) && !options[:if].call(self)
              checkout_steps << step
            }.map(&:to_s)
            # Ensure there is always a complete step
            steps << "complete" unless steps.include?("complete")
            steps
          end

          def has_checkout_step?(step)
            step.present? && self.checkout_steps.include?(step)
          end

          def passed_checkout_step?(step)
            has_checkout_step?(step) && checkout_step_index(step) < checkout_step_index(self.state)
          end

          def checkout_step_index(step)
            self.checkout_steps.index(step).to_i
          end

          def self.removed_transitions
            @removed_transitions ||= []
          end

          def can_go_to_state?(state)
            return false unless has_checkout_step?(self.state) && has_checkout_step?(state)
            checkout_step_index(state) > checkout_step_index(self.state)
          end

          define_callbacks :updating_from_params, terminator: ->(target, result) { result == false }

          set_callback :updating_from_params, :before, :update_params_payment_source

          def update_from_params(params, permitted_params, request_env = {})
            success = false
            @updating_params = params
            run_callbacks :updating_from_params do
              attributes = @updating_params[:order] ? @updating_params[:order].permit(permitted_params).delete_if { |k,v| v.nil? } : {}

              # Set existing card after setting permitted parameters because
              # rails would slice parameters containg ruby objects, apparently
              existing_card_id = @updating_params[:order] ? @updating_params[:order][:existing_card] : nil

              if existing_card_id.present?
                credit_card = CreditCard.find existing_card_id
                if credit_card.user_id != self.user_id || credit_card.user_id.blank?
                  raise Core::GatewayError.new Spree.t(:invalid_credit_card)
                end

                credit_card.verification_value = params[:cvc_confirm] if params[:cvc_confirm].present?

                attributes[:payments_attributes].first[:source] = credit_card
                attributes[:payments_attributes].first[:payment_method_id] = credit_card.payment_method_id
                attributes[:payments_attributes].first.delete :source_attributes
              end

              if attributes[:payments_attributes]
                attributes[:payments_attributes].first[:request_env] = request_env
              end

              success = self.update_attributes(attributes)
              set_shipments_cost if self.shipments.any?
            end

            @updating_params = nil
            success
          end

          def assign_default_addresses!
            if self.user
              self.bill_address = user.bill_address.try(:clone) if !self.bill_address_id && user.bill_address.try(:valid?)
              # Skip setting ship address if order doesn't have a delivery checkout step
              # to avoid triggering validations on shipping address
              self.ship_address = user.ship_address.try(:clone) if !self.ship_address_id && user.ship_address.try(:valid?) && self.checkout_steps.include?("delivery")
            end
          end

          def persist_user_address!
            if !self.temporary_address && self.user && self.user.respond_to?(:persist_order_address) && self.bill_address_id
              self.user.persist_order_address(self)
            end
          end

          def persist_user_credit_card
            if !self.temporary_credit_card && self.user_id && self.valid_credit_cards.present?
              default_cc = self.valid_credit_cards.first
              default_cc.user_id = self.user_id
              default_cc.default = true
              default_cc.save
            end
          end

          def assign_default_credit_card
            if self.payments.from_credit_card.count == 0 && self.user && self.user.default_credit_card.try(:valid?)
              cc = self.user.default_credit_card
              self.payments.create!(payment_method_id: cc.payment_method_id, source: cc)
            end
          end

          private
          # For payment step, filter order parameters to produce the expected nested
          # attributes for a single payment and its source, discarding attributes
          # for payment methods other than the one selected
          #
          # In case a existing credit card is provided it needs to build the payment
          # attributes from scratch so we can set the amount. example payload:
          #
          #   {
          #     "order": {
          #       "existing_card": "2"
          #     }
          #   }
          #
          def update_params_payment_source
            if @updating_params[:payment_source].present?
              source_params = @updating_params.delete(:payment_source)[@updating_params[:order][:payments_attributes].first[:payment_method_id].to_s]

              if source_params
                @updating_params[:order][:payments_attributes].first[:source_attributes] = source_params
              end
            end

            if @updating_params[:order] && (@updating_params[:order][:payments_attributes] || @updating_params[:order][:existing_card])
              @updating_params[:order][:payments_attributes] ||= [{}]
              @updating_params[:order][:payments_attributes].first[:amount] = self.total
            end
          end
        end
      end
    end
  end
end
