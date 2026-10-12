module Spree
  module Api
    module V3
      # The money summary a cart, an order and a multi-seller purchase all
      # carry, declared once so a storefront renders any of them with one
      # component, and a fix to one is a fix to all three.
      #
      # Every amount is nulled for a guest the storefront hides prices from,
      # the payments' own included.
      module PurchaseSummary
        extend ActiveSupport::Concern

        included do
          typelize covered_by_store_credit: :boolean

          money_attributes :item_total, :display_item_total,
                           :discount_total, :display_discount_total,
                           :tax_total, :display_tax_total,
                           :included_tax_total, :display_included_tax_total,
                           :additional_tax_total, :display_additional_tax_total,
                           :delivery_total, :display_delivery_total,
                           :fee_total, :display_fee_total,
                           :gift_card_total, :display_gift_card_total,
                           :store_credit_total, :display_store_credit_total,
                           :total, :display_total,
                           :amount_due, :display_amount_due

          attribute :covered_by_store_credit, &:covered_by_store_credit?

          many :payments, resource: proc { Spree.api.payment_serializer }
        end
      end
    end
  end
end
