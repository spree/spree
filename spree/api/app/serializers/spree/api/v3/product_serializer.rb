module Spree
  module Api
    module V3
      # Store API Product Serializer
      # Customer-facing product data with limited fields
      class ProductSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true], description_html: [:string, nullable: true], slug: :string,
                 meta_description: [:string, nullable: true], meta_keywords: [:string, nullable: true],
                 variant_count: :number,
                 default_variant_id: :string,
                 thumbnail_url: [:string, nullable: true],
                 available_on: [:string, nullable: true],
                 purchasable: :boolean, in_stock: :boolean, backorderable: :boolean, available: :boolean,
                 price: 'Price',
                 original_price: ['Price', nullable: true],
                 tags: [:string, multi: true]

        attributes :name, :slug,
                   :meta_description, :meta_keywords,
                   :variant_count,
                   available_on: :iso8601, created_at: :iso8601, updated_at: :iso8601

        attribute :purchasable do |product|
          product.purchasable?
        end

        attribute :in_stock do |product|
          product.in_stock?
        end

        attribute :backorderable do |product|
          product.backorderable?
        end

        attribute :available do |product|
          product.available?
        end

        attribute :description do |product|
          next if product.description.blank?

          Nokogiri::HTML.fragment(product.description).text.squish
        end

        attribute :description_html do |product|
          product.description
        end

        attribute :default_variant_id do |product|
          product.default_variant&.prefixed_id
        end

        # Main product image URL for listings (cached primary_media)
        attribute :thumbnail_url do |product|
          image_url_for(product.primary_media)
        end

        attribute :tags do |product|
          product.taggings.map(&:tag)
        end

        # Price object - calculated price with price list resolution
        attribute :price do |product|
          price = price_for(product.default_variant)
          Spree.api.price_serializer.new(price, params: params).to_h if price.present?
        end

        # Original price - base price without price list resolution (for showing strikethrough)
        # Returns null when same as calculated price, only populated when a price list discount is applied
        attribute :original_price do |product|
          variant = product.default_variant
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

        many :variants,
             resource: Spree.api.variant_serializer,
             if: proc { expand?('variants') }

        one :default_variant,
            resource: Spree.api.variant_serializer,
            if: proc { expand?('default_variant') }

        many :option_types,
             resource: Spree.api.option_type_serializer,
             if: proc { expand?('option_types') }

        many :taxons,
             proc { |taxons, params|
               taxons.select { |t| t.taxonomy.store_id == params[:store].id }
             },
             key: :categories,
             resource: Spree.api.category_serializer,
             if: proc { expand?('categories') }

        many :public_metafields,
             key: :metafields,
             resource: Spree.api.metafield_serializer,
             if: proc { expand?('metafields') }

        typelize prior_price: ['PriceHistory', nullable: true]

        attribute :prior_price,
                  if: proc { expand?('prior_price') } do |product|
          record = price_in(product.default_variant)&.prior_price
          Spree.api.price_history_serializer.new(record, params: params).to_h if record
        end
      end
    end
  end
end
