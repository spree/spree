module Spree
  module Api
    module V3
      # Store API Product Serializer
      # Customer-facing product data with limited fields
      class ProductSerializer < BaseSerializer
        typelize name: :string, description: 'string | null', slug: :string,
                 sku: 'string | null', barcode: 'string | null',
                 meta_description: 'string | null', meta_keywords: 'string | null',
                 variant_count: :number,
                 available_on: 'string | null',
                 purchasable: :boolean, in_stock: :boolean, backorderable: :boolean, available: :boolean,
                 price: 'number | null', price_in_cents: 'number | null', display_price: 'string | null',
                 compare_at_price: 'number | null', compare_at_price_in_cents: 'number | null',
                 display_compare_at_price: 'string | null', tags: 'string[]'

        attributes :name, :description, :slug, :sku, :barcode,
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

        attribute :price do |product|
          price_object(product)&.amount&.to_f
        end

        attribute :price_in_cents do |product|
          price_object(product)&.display_amount&.amount_in_cents
        end

        attribute :display_price do |product|
          price_object(product)&.display_price&.to_s
        end

        attribute :compare_at_price do |product|
          price_object(product)&.compare_at_amount&.to_f
        end

        attribute :compare_at_price_in_cents do |product|
          price_object(product)&.display_compare_at_amount&.amount_in_cents if price_object(product)&.compare_at_amount&.present?
        end

        attribute :display_compare_at_price do |product|
          price_object(product)&.display_compare_at_amount&.to_s if price_object(product)&.compare_at_amount&.present?
        end

        attribute :tags do |product|
          product.taggings.map(&:tag)
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

        private

        def price_object(product)
          @price_object ||= price_for(product.default_variant)
        end
      end
    end
  end
end
