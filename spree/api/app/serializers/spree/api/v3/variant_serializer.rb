module Spree
  module Api
    module V3
      # Store API Variant Serializer
      # Customer-facing variant data with limited fields
      class VariantSerializer < BaseSerializer
        typelize product_id: :string, sku: [:string, nullable: true],
                 options_text: :string, track_inventory: :boolean, media_count: :number,
                 thumbnail_url: [:string, nullable: true],
                 purchasable: :boolean, in_stock: :boolean, backorderable: :boolean,
                 weight: [:number, nullable: true], height: [:number, nullable: true], width: [:number, nullable: true], depth: [:number, nullable: true],
                 price: 'Price',
                 original_price: ['Price', nullable: true]

        attribute :product_id do |variant|
          variant.product&.prefixed_id
        end

        attributes :sku, :options_text, :track_inventory, :media_count,
                   created_at: :iso8601, updated_at: :iso8601

        # Main variant image URL for listings (cached primary_media)
        attribute :thumbnail_url do |variant|
          image_url_for(variant.primary_media)
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
        one :primary_media,
            resource: Spree.api.media_serializer,
            if: proc { expand?('primary_media') }

        many :gallery_media,
             key: :media,
             resource: Spree.api.media_serializer,
             if: proc { expand?('media') }

        many :option_values, resource: Spree.api.option_value_serializer

        many :public_metafields,
             key: :metafields,
             resource: Spree.api.metafield_serializer,
             if: proc { expand?('metafields') }

        typelize prior_price: ['PriceHistory', nullable: true]

        attribute :prior_price,
                  if: proc { expand?('prior_price') } do |variant|
          record = price_in(variant)&.prior_price
          Spree.api.price_history_serializer.new(record, params: params).to_h if record
        end
      end
    end
  end
end
