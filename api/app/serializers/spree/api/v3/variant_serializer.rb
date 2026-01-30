module Spree
  module Api
    module V3
      # Store API Variant Serializer
      # Customer-facing variant data with limited fields
      class VariantSerializer < BaseSerializer

        typelize product_id: :string, sku: 'string | null', barcode: 'string | null',
                 is_master: :boolean, options_text: :string, track_inventory: :boolean, image_count: :number,
                 purchasable: :boolean, in_stock: :boolean, backorderable: :boolean,
                 weight: 'number | null', height: 'number | null', width: 'number | null', depth: 'number | null',
                 price: 'number | null', price_in_cents: 'number | null', display_price: 'string | null',
                 compare_at_price: 'number | null', compare_at_price_in_cents: 'number | null', display_compare_at_price: 'string | null',
                 original_price: 'number | null', original_price_in_cents: 'number | null', display_original_price: 'string | null',
                 on_sale: :boolean, price_list_id: 'string | null'

        attribute :product_id do |variant|
          variant.product&.prefix_id
        end

        attributes :sku, :barcode, :is_master, :options_text, :track_inventory, :image_count,
                   created_at: :iso8601, updated_at: :iso8601

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

        attribute :price_in_cents do |variant|
          price_object(variant)&.display_amount&.amount_in_cents
        end

        attribute :display_price do |variant|
          price_object(variant)&.display_price&.to_s
        end

        attribute :compare_at_price do |variant|
          price_object(variant)&.compare_at_amount&.to_f
        end

        attribute :compare_at_price_in_cents do |variant|
          price = price_object(variant)
          next unless price&.compare_at_amount.present?

          Spree::Money.new(price.compare_at_amount, currency: current_currency).amount_in_cents
        end

        attribute :display_compare_at_price do |variant|
          price = price_object(variant)
          next unless price&.compare_at_amount.present?

          Spree::Money.new(price.compare_at_amount, currency: current_currency).to_s
        end

        # Original price (base price without price list resolution)
        attribute :original_price do |variant|
          original_price_object(variant)&.amount&.to_f
        end

        attribute :original_price_in_cents do |variant|
          original_price_object(variant)&.display_amount&.amount_in_cents
        end

        attribute :display_original_price do |variant|
          original_price_object(variant)&.display_price&.to_s
        end

        # Whether the variant is on sale (price list applied or compare_at_price set)
        attribute :on_sale do |variant|
          price = price_object(variant)
          original = original_price_object(variant)

          next false unless price&.amount.present?

          # On sale if: price list applied with lower price, OR compare_at_price is higher
          from_price_list = price.price_list_id.present? && original&.amount.present? && price.amount < original.amount
          has_compare_at = price.compare_at_amount.present? && price.amount < price.compare_at_amount

          from_price_list || has_compare_at
        end

        # ID of the price list if one was applied
        attribute :price_list_id do |variant|
          price = price_object(variant)
          next nil unless price&.price_list_id.present?

          Spree::PriceList.find_by(id: price.price_list_id)&.prefix_id
        end

        # Conditional associations
        many :images,
             resource: Spree.api.image_serializer,
             if: proc { params[:includes]&.include?('images') }

        many :option_values, resource: Spree.api.option_value_serializer

        private

        def price_object(variant)
          @price_object ||= price_for(variant)
        end

        def original_price_object(variant)
          @original_price_object ||= price_in(variant)
        end
      end
    end
  end
end
