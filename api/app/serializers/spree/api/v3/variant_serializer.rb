module Spree
  module Api
    module V3
      class VariantSerializer < BaseSerializer
        attributes :id, :name, :sku, :barcode, :is_master, :options_text

        attribute :purchasable do |variant|
          variant.purchasable?
        end

        attribute :in_stock do |variant|
          variant.in_stock?
        end

        attribute :backorderable do |variant|
          variant.backorderable?
        end

        attribute :weight do |variant|
          variant.weight&.to_f
        end

        attribute :height do |variant|
          variant.height&.to_f
        end

        attribute :width do |variant|
          variant.width&.to_f
        end

        attribute :depth do |variant|
          variant.depth&.to_f
        end

        attribute :price do |variant|
          price_object(variant)&.amount&.to_f
        end

        attribute :display_price do |variant|
          price_object(variant)&.display_price&.to_s
        end

        attribute :compare_at_price do |variant|
          price_object(variant)&.compare_at_amount&.to_f
        end

        attribute :display_compare_at_price do |variant|
          price = price_object(variant)
          next unless price&.compare_at_amount

          Spree::Money.new(price.compare_at_amount, currency: currency).to_s
        end

        # Conditional associations
        many :images,
             resource: Spree.api.v3_storefront_image_serializer,
             if: proc { params[:includes]&.include?('images') }

        many :option_values,
             resource: Spree.api.v3_storefront_option_value_serializer,
             if: proc { params[:includes]&.include?('option_values') }

        private

        def price_object(variant)
          @price_object ||= price_for(variant)
        end
      end
    end
  end
end
