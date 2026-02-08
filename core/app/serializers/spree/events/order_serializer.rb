# frozen_string_literal: true

module Spree
  module Events
    class OrderSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          number: resource.number,
          state: resource.state.to_s,
          payment_state: resource.payment_state.to_s,
          shipment_state: resource.shipment_state.to_s,
          total: money(resource.total),
          item_total: money(resource.item_total),
          shipment_total: money(resource.shipment_total),
          adjustment_total: money(resource.adjustment_total),
          promo_total: money(resource.promo_total),
          included_tax_total: money(resource.included_tax_total),
          additional_tax_total: money(resource.additional_tax_total),
          item_count: resource.item_count,
          currency: resource.currency,
          email: resource.email,
          user_id: public_id(resource.user),
          store_id: public_id(resource.store),
          canceler_id: public_id(resource.canceler),
          approver_id: public_id(resource.approver),
          considered_risky: resource.considered_risky,
          completed_at: timestamp(resource.completed_at),
          canceled_at: timestamp(resource.canceled_at),
          approved_at: timestamp(resource.approved_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
