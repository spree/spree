module Spree
  module Api
    module V3
      # Store API Variant Serializer
      # Customer-facing variant data with limited fields
      class VariantSerializer < BaseSerializer
        typelize product_id: :string, sku: 'string | null',
                 is_master: :boolean, options_text: :string, track_inventory: :boolean, image_count: :number,
                 thumbnail: 'string | null',
                 purchasable: :boolean, in_stock: :boolean, backorderable: :boolean,
                 weight: 'number | null', height: 'number | null', width: 'number | null', depth: 'number | null',
                 price: 'StorePrice',
                 original_price: 'StorePrice | null'

        attribute :product_id do |variant|
          variant.product&.prefix_id
        end

        attributes :sku, :is_master, :options_text, :track_inventory, :image_count,
                   created_at: :iso8601, updated_at: :iso8601

        # Main variant image URL for listings (cached thumbnail)
        attribute :thumbnail do |variant|
          image_url_for(variant.thumbnail)
        end

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

        # Price object - calculated price with price list resolution
        attribute :price do |variant|
          price = price_for(variant)
          Spree.api.price_serializer.new(price, params: params).to_h if price.present?
        end

        # Original price - base price without price list resolution (for showing strikethrough)
        # Returns null when same as calculated price, only populated when a price list discount is applied
        attribute :original_price do |variant|
          calculated = price_for(variant)
          base = price_in(variant)

          if calculated.present? && base.present? && calculated.id != base.id
            Spree.api.price_serializer.new(base, params: params).to_h
          end
        end

        # Conditional associations
        many :images,
             resource: Spree.api.image_serializer,
             if: proc { params[:includes]&.include?('images') }

        many :option_values, resource: Spree.api.option_value_serializer

        many :public_metafields,
             key: :metafields,
             resource: Spree.api.metafield_serializer,
             if: proc { params[:includes]&.include?('metafields') }
      end
    end
  end
end
