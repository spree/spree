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

          self.checkout_steps ||= {}
          self.next_event_transitions ||= []
          self.previous_states ||= [:cart]
          self.removed_transitions ||= []

          def self.checkout_flow(&block)
            if block_given?
              @checkout_flow = block
              define_state_machine!
            else
              @checkout_flow
            end
          end

          def self.define_state_machine!
            self.checkout_steps = {}
            self.next_event_transitions = []
            self.previous_states = [:cart]
            self.removed_transitions = []

            # Build the checkout flow using the checkout_flow defined either
            # within the Order class, or a decorator for that class.
            #
            # This method may be called multiple times depending on if the
            # checkout_flow is re-defined in a decorator or not.
            instance_eval(&checkout_flow)

            klass = self

            # To avoid a ton of warnings when the state machine is re-defined
            StateMachines::Machine.ignore_method_conflicts = true
            # To avoid multiple occurrences of the same transition being defined
            # On first definition, state_machines will not be defined
            state_machines.clear if respond_to?(:state_machines)
            state_machine :state, initial: :cart, use_transactions: false, action: :save_state do
              klass.next_event_transitions.each { |t| transition(t.merge(on: :next)) }

              # Persist the state on the order
              after_transition do |order, transition|
                order.state = order.state
                order.state_changes.create(
                  previous_state: transition.from,
                  next_state: transition.to,
                  name: 'order',
                  user_id: order.user_id
                )
                order.save
              end

              event :cancel do
                transition to: :canceled, if: :allow_cancel?
              end

              event :return do
                transition to: :returned,
                           from: [:complete, :awaiting_return, :canceled],
                           if: :all_inventory_units_returned?
              end

              event :resume do
                transition to: :resumed, from: :canceled, if: :canceled?
              end

              event :authorize_return do
                transition to: :awaiting_return
              end

              if states[:payment]
                before_transition to: :complete do |order|
                  if order.payment_required? && order.payments.valid.empty?
                    order.errors.add(:base, Spree.t(:no_payment_found))
                    false
                  elsif order.payment_required?
                    order.process_payments!
                  end
                end
                after_transition to: :complete, do: :persist_user_credit_card
                before_transition to: :payment, do: :set_shipments_cost
                before_transition to: :payment, do: :create_tax_charge!
              end

              before_transition from: :cart, do: :ensure_line_items_present

              if states[:address]
                before_transition from: :address, do: :update_line_item_prices!
                before_transition from: :address, do: :create_tax_charge!
                before_transition to: :address, do: :assign_default_addresses!
                before_transition from: :address, do: :persist_user_address!
              end

              if states[:delivery]
                before_transition to: :delivery, do: :create_proposed_shipments
                before_transition to: :delivery, do: :ensure_available_shipping_rates
                before_transition to: :delivery, do: :set_shipments_cost
                before_transition from: :delivery, do: :apply_free_shipping_promotions
              end

              before_transition to: :resumed, do: :ensure_line_item_variants_are_not_discontinued
              before_transition to: :resumed, do: :ensure_line_items_are_in_stock

              before_transition to: :complete, do: :ensure_line_item_variants_are_not_discontinued
              before_transition to: :complete, do: :ensure_line_items_are_in_stock

              after_transition to: :complete, do: :finalize!
              after_transition to: :resumed, do: :after_resume
              after_transition to: :canceled, do: :after_cancel

              after_transition from: any - :cart, to: any - [:confirm, :complete] do |order|
                order.update_totals
                order.persist_totals
              end
            end

            alias_method :save_state, :save
          end

          def self.go_to_state(name, options = {})
            self.checkout_steps[name] = options
            previous_states.each do |state|
              add_transition({ from: state, to: name }.merge(options))
            end
            if options[:if]
              previous_states << name
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
            checkout_flow do
              cloned_steps.each_pair do |key, value|
                go_to_state(name, options) if key == before
                go_to_state(key, value)
                go_to_state(name, options) if key == after
              end
              cloned_removed_transitions.each do |transition|
                remove_transition(transition)
              end
            end
          end

          def self.remove_checkout_step(name)
            cloned_steps = self.checkout_steps.clone
            cloned_removed_transitions = self.removed_transitions.clone
            checkout_flow do
              cloned_steps.each_pair do |key, value|
                go_to_state(key, value) unless key == name
              end
              cloned_removed_transitions.each do |transition|
                remove_transition(transition)
              end
            end
          end

          def self.remove_transition(options = {})
            self.removed_transitions << options
            self.next_event_transitions.delete(find_transition(options))
          end

          def self.find_transition(options = {})
            return nil if options.nil? || !options.include?(:from) || !options.include?(:to)
            self.next_event_transitions.detect do |transition|
              transition[options[:from].to_sym] == options[:to].to_sym
            end
          end

          def self.checkout_step_names
            self.checkout_steps.keys
          end

          def self.add_transition(options)
            self.next_event_transitions << { options.delete(:from) => options.delete(:to) }.merge(options)
          end

          def checkout_steps
            steps = (self.class.checkout_steps.each_with_object([]) do |(step, options), checkout_steps|
              next if options.include?(:if) && !options[:if].call(self)
              checkout_steps << step
            end).map(&:to_s)
            # Ensure there is always a complete step
            steps << "complete" unless steps.include?("complete")
            steps
          end

          def has_checkout_step?(step)
            step.present? && self.checkout_steps.include?(step)
          end

          def passed_checkout_step?(step)
            has_checkout_step?(step) && checkout_step_index(step) < checkout_step_index(state)
          end

          def checkout_step_index(step)
            self.checkout_steps.index(step).to_i
          end

          def can_go_to_state?(state)
            return false unless has_checkout_step?(self.state) && has_checkout_step?(state)
            checkout_step_index(state) > checkout_step_index(self.state)
          end

          define_callbacks :updating_from_params, terminator: ->(_target, result) { result == false }

          set_callback :updating_from_params, :before, :update_params_payment_source

          def update_from_params(params, permitted_params, request_env = {})
            success = false
            @updating_params = params
            run_callbacks :updating_from_params do
              # Set existing card after setting permitted parameters because
              # rails would slice parameters containg ruby objects, apparently
              existing_card_id = @updating_params[:order] ? @updating_params[:order].delete(:existing_card) : nil

              attributes = @updating_params[:order] ? @updating_params[:order].permit(permitted_params).delete_if { |_k, v| v.nil? } : {}

              if existing_card_id.present?
                credit_card = CreditCard.find existing_card_id
                if credit_card.user_id != user_id || credit_card.user_id.blank?
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

              success = update_attributes(attributes)
              set_shipments_cost if shipments.any?
            end

            @updating_params = nil
            success
          end

          def assign_default_addresses!
            if user
              clone_billing
              # Skip setting ship address if order doesn't have a delivery checkout step
              # to avoid triggering validations on shipping address
              clone_shipping if checkout_steps.include?("delivery")
            end
          end

          def clone_billing
            if !bill_address_id && user.bill_address.try(:valid?)
              self.bill_address = user.bill_address.try(:clone)
            end
          end

          def clone_shipping
            if !ship_address_id && user.ship_address.try(:valid?)
              self.ship_address = user.ship_address.try(:clone)
            end
          end

          def persist_user_address!
            if !temporary_address && user && user.respond_to?(:persist_order_address) && bill_address_id
              user.persist_order_address(self)
            end
          end

          def persist_user_credit_card
            if !temporary_credit_card && user_id && valid_credit_cards.present?
              valid_credit_cards.first.update(user_id: user_id, default: true)
            end
          end

          def assign_default_credit_card
            if payments.from_credit_card.size == 0 && user_has_valid_default_card? && payment_required?
              cc = user.default_credit_card
              payments.create!(payment_method_id: cc.payment_method_id, source: cc, amount: total)
            end
          end

          def user_has_valid_default_card?
            user && user.default_credit_card.try(:valid?)
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
              source_params = @updating_params.
                              delete(:payment_source)[@updating_params[:order][:payments_attributes].
                                                      first[:payment_method_id].to_s]

              if source_params
                @updating_params[:order][:payments_attributes].first[:source_attributes] = source_params
              end
            end

            if @updating_params[:order] && (@updating_params[:order][:payments_attributes] ||
                                            @updating_params[:order][:existing_card])
              @updating_params[:order][:payments_attributes] ||= [{}]
              @updating_params[:order][:payments_attributes].first[:amount] = total
            end
          end
        end
      end
    end
  end
end
