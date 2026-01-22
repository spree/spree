module Spree
  module Api
    module V3
      module Store
        class ProductSerializer < BaseSerializer
          attributes :id, :name, :description, :slug, :sku, :barcode,
                    :meta_description, :meta_keywords,
                    available_on: :iso8601

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
              resource: Spree.api.v3_store_image_serializer,
              if: proc { params[:includes]&.include?('images') }

          many :variants,
              resource: Spree.api.v3_store_variant_serializer,
              if: proc { params[:includes]&.include?('variants') }

          one :default_variant,
              resource: Spree.api.v3_store_variant_serializer,
              if: proc { params[:includes]&.include?('default_variant') }

          one :master,
              key: :master_variant,
              resource: Spree.api.v3_store_variant_serializer,
              if: proc { params[:includes]&.include?('master_variant') }

          many :option_types,
              resource: Spree.api.v3_store_option_type_serializer,
              if: proc { params[:includes]&.include?('option_types') }

          many :taxons,
              proc { |taxons, params|
                taxons.select { |t| t.taxonomy.store_id == params[:store].id}
                },
              resource: Spree.api.v3_store_taxon_serializer,
              if: proc { params[:includes]&.include?('taxons') }

          private

          def price_object(product)
            @price_object ||= price_for(product.default_variant)
          end
        end
      end
    end
  end
end
