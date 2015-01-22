module Spree
  module StateMachines
    class Order
      include Statesman::Machine

      state :awaiting_return
      state :canceled
      state :cart, initial: true
      state :complete
      state :payment
      state :resumed
      state :returned

      Spree::Order.next_event_transitions.each { |t| transition(t.merge(on: :next)) }

      # Persist the state on the order
      after_transition do |order, transition|
        order.state = transition.to_state
        order.state_changes.build(
          previous_state: transition.from_state,
          next_state:     transition.to_state,
          name:           'order',
          user_id:        order.user_id
        )
        order.save!
      end

      before_transition from: :cart do |order, transition|
        order.ensure_line_items_present
      end

      event :authorize_return do
        transition to: :awaiting_return
      end

      event :cancel do
        transition to: :canceled
      end

      event :resume do
        transition to: :resumed, from: :canceled, if: :canceled?
      end

      event :return do
        transition to: :returned, from: [:complete, :awaiting_return, :canceled], if: :all_inventory_units_returned?
      end

      if states[:payment]
        after_transition to: :complete do |order|
          order.persist_user_credit_card
        end

        before_transition to: :complete do |order|
          if order.payment_required? && order.payments.valid.empty?
            order.errors.add(:base, Spree.t(:no_payment_found))
            false
          elsif order.payment_required?
            order.process_payments!
          end
        end

        before_transition to: :payment do |order|
          order.set_shipments_cost
          order.create_tax_charge!
          order.assign_default_credit_card
        end
      end

      if states[:address]
        before_transition from: :address do |order|
          order.create_tax_charge!
          order.persist_user_address!
        end

        before_transition to: :address do |order|
          order.assign_default_addresses!
        end
      end

      if states[:delivery]
        before_transition from: :delivery do |order|
          order.apply_free_shipping_promotions
        end

        before_transition to: :delivery do |order|
          order.create_proposed_shipments
          order.ensure_available_shipping_rates
          order.set_shipments_cost
        end
      end

      before_transition to: :resumed do |order|
        order.ensure_line_item_variants_are_not_deleted
        order.ensure_line_items_are_in_stock
      end

      before_transition to: :complete do |order|
        order.ensure_line_item_variants_are_not_deleted
        order.ensure_line_items_are_in_stock
      end

      after_transition to: :complete do |order|
        order.finalize!
      end

      after_transition to: :resumed do |order|
        order.after_resume
      end

      after_transition to: :canceled do |order|
        order.after_cancel
      end

      after_transition from: any - :cart, to: any - [:confirm, :complete] do |order|
        order.update_totals
        order.persist_totals
      end

      guard_transition(to: :canceled) do |order|
        order.allow_cancel?
      end
    end
  end
end
