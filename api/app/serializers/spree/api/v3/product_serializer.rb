module Spree
  module Api
    module V3
      # Store API Product Serializer
      # Customer-facing product data with limited fields
      class ProductSerializer < BaseSerializer
        typelize name: :string, description: 'string | null', slug: :string,
                 meta_description: 'string | null', meta_keywords: 'string | null',
                 variant_count: :number,
                 default_variant_id: :string,
                 available_on: 'string | null',
                 purchasable: :boolean, in_stock: :boolean, backorderable: :boolean, available: :boolean,
                 price: 'StorePrice',
                 original_price: 'StorePrice',
                 tags: 'string[]'

        attributes :name, :description, :slug,
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

        attribute :default_variant_id do |product|
          product.default_variant&.prefix_id
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
        attribute :original_price do |product|
          price = price_in(product.default_variant)
          Spree.api.price_serializer.new(price, params: params).to_h if price.present?
        end

        # Conditional associations
        many :variant_images,
             key: :images,
             resource: Spree.api.image_serializer,
             if: proc { params[:includes]&.include?('images') }

        many :variants,
             resource: Spree.api.variant_serializer,
             if: proc { params[:includes]&.include?('variants') }

        one :default_variant,
            resource: Spree.api.variant_serializer,
            if: proc { params[:includes]&.include?('default_variant') }

        one :master,
            key: :master_variant,
            resource: Spree.api.variant_serializer,
            if: proc { params[:includes]&.include?('master_variant') }

        many :option_types,
             resource: Spree.api.option_type_serializer,
             if: proc { params[:includes]&.include?('option_types') }

        many :taxons,
             proc { |taxons, params|
               taxons.select { |t| t.taxonomy.store_id == params[:store].id }
             },
             resource: Spree.api.taxon_serializer,
             if: proc { params[:includes]&.include?('taxons') }
      end
    end
  end
end
