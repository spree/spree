module Spree
  module Api
    module V3
      class LineItemSerializer < BaseSerializer
        attributes :id, :variant_id, :quantity, :currency

        attribute :price do |line_item|
          line_item.price.to_f
        end

        attribute :display_price do |line_item|
          line_item.display_price.to_s
        end

        attribute :total do |line_item|
          line_item.total.to_f
        end

        attribute :display_total do |line_item|
          line_item.display_total.to_s
        end

        attribute :adjustment_total do |line_item|
          line_item.adjustment_total.to_f
        end

        attribute :display_adjustment_total do |line_item|
          line_item.display_adjustment_total.to_s
        end

        attribute :promo_total do |line_item|
          line_item.promo_total.to_f
        end

        attribute :display_promo_total do |line_item|
          line_item.display_promo_total.to_s
        end

        attribute :included_tax_total do |line_item|
          line_item.included_tax_total.to_f
        end

        attribute :display_included_tax_total do |line_item|
          line_item.display_included_tax_total.to_s
        end

        attribute :additional_tax_total do |line_item|
          line_item.additional_tax_total.to_f
        end

        attribute :display_additional_tax_total do |line_item|
          line_item.display_additional_tax_total.to_s
        end

        attribute :pre_tax_amount do |line_item|
          line_item.pre_tax_amount.to_f
        end

        attribute :display_pre_tax_amount do |line_item|
          line_item.display_pre_tax_amount.to_s
        end

        attribute :compare_at_amount do |line_item|
          line_item.compare_at_amount.to_f
        end

        attribute :display_compare_at_amount do |line_item|
          line_item.display_compare_at_amount.to_s
        end

        attribute :discounted_amount do |line_item|
          line_item.discounted_amount.to_f
        end

        attribute :display_discounted_amount do |line_item|
          line_item.display_discounted_amount.to_s
        end

        # Conditional associations
        one :variant,
            resource: Spree.api.v3_storefront_variant_serializer,
            if: proc { params[:includes]&.include?('variant') }

        one :product,
            resource: Spree.api.v3_storefront_product_serializer,
            if: proc { params[:includes]&.include?('product') }
      end
    end
  end
end
