# frozen_string_literal: true

module Spree
  module Events
    class LineItemSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          quantity: resource.quantity,
          price: money(resource.price),
          currency: resource.currency,
          cost_price: money(resource.cost_price),
          adjustment_total: money(resource.adjustment_total),
          additional_tax_total: money(resource.additional_tax_total),
          promo_total: money(resource.promo_total),
          included_tax_total: money(resource.included_tax_total),
          pre_tax_amount: money(resource.pre_tax_amount),
          taxable_adjustment_total: money(resource.taxable_adjustment_total),
          non_taxable_adjustment_total: money(resource.non_taxable_adjustment_total),
          variant_id: resource.variant_id,
          order_id: resource.order_id,
          tax_category_id: resource.tax_category_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
