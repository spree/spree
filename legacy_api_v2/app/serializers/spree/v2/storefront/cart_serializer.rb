module Spree
  module V2
    module Storefront
      class CartSerializer < BaseSerializer
        include Spree::Api::V2::PublicMetafieldsConcern

        set_type :cart

        attributes :number, :item_total, :total, :ship_total, :adjustment_total, :created_at,
                   :updated_at, :completed_at, :included_tax_total, :additional_tax_total, :display_additional_tax_total,
                   :display_included_tax_total, :tax_total, :currency, :state, :token, :email,
                   :display_item_total, :display_ship_total, :display_adjustment_total, :display_tax_total,
                   :promo_total, :display_promo_total, :item_count, :special_instructions, :display_total,
                   :pre_tax_item_amount, :display_pre_tax_item_amount, :pre_tax_total, :display_pre_tax_total,
                   :shipment_state, :payment_state, :public_metadata, :total_minus_store_credits, :display_total_minus_store_credits

        attribute :subtotal_cents do |cart|
          cart.display_item_total.amount_in_cents
        end

        attribute :ship_total_cents do |cart|
          cart.display_ship_total.amount_in_cents
        end

        attribute :store_credit_total_cents do |cart|
          cart.display_total_applied_store_credit.abs.amount_in_cents
        end

        attribute :promo_total_cents do |cart|
          cart.display_promo_total.abs.amount_in_cents
        end

        attribute :tax_total_cents do |cart|
          cart.display_tax_total.amount_in_cents
        end

        attribute :total_cents do |cart|
          cart.display_total.amount_in_cents
        end

        attribute :total_minus_store_credits_cents do |cart|
          cart.display_total_minus_store_credits.amount_in_cents
        end

        has_many   :line_items, serializer: Spree.api.storefront_line_item_serializer
        has_many   :variants, serializer: Spree.api.storefront_variant_serializer
        has_many   :promotions, serializer: Spree.api.storefront_order_promotion_serializer, object_method_name: :valid_promotions, id_method_name: :valid_promotion_ids
        has_many   :payments, serializer: Spree.api.storefront_payment_serializer do |cart|
          cart.payments.valid
        end
        has_many   :shipments, serializer: Spree.api.storefront_shipment_serializer

        belongs_to :user, serializer: Spree.api.storefront_user_serializer
        belongs_to :billing_address,
                   id_method_name: :bill_address_id,
                   serializer: Spree.api.storefront_address_serializer,
                   record_type: :address

        belongs_to :shipping_address,
                   id_method_name: :ship_address_id,
                   serializer: Spree.api.storefront_address_serializer,
                   record_type: :address
        belongs_to :gift_card, serializer: Spree.api.storefront_gift_card_serializer
      end
    end
  end
end
