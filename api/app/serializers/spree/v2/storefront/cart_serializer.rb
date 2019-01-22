module Spree
  module V2
    module Storefront
      class CartSerializer < BaseSerializer
        set_type :cart

        attributes :number, :item_total, :total, :ship_total, :adjustment_total, :created_at,
                   :updated_at, :completed_at, :included_tax_total, :additional_tax_total, :display_additional_tax_total,
                   :display_included_tax_total, :tax_total, :currency, :state, :token, :email,
                   :display_item_total, :display_ship_total, :display_adjustment_total, :display_tax_total,
                   :promo_total, :display_promo_total, :item_count, :special_instructions, :display_total

        has_many   :line_items
        has_many   :variants
        has_many   :promotions, id_method_name: :promotion_id do |cart|
          # we only want to display applied and valid promotions
          # sometimes Order can have multiple promotions but the promo engine
          # will only apply those that are more beneficial for the customer
          # TODO: we should probably move this code out of the serializer
          promotion_ids = cart.all_adjustments.eligible.nonzero.promotion.map { |a| a.source.promotion_id }.uniq

          cart.order_promotions.where(promotion_id: promotion_ids).uniq(&:promotion_id)
        end
        has_many   :payments do |cart|
          cart.payments.valid
        end
        has_many   :shipments

        belongs_to :user
        belongs_to :billing_address,
          id_method_name: :bill_address_id,
          serializer: :address

        belongs_to :shipping_address,
          id_method_name: :ship_address_id,
          serializer: :address
      end
    end
  end
end
