module Spree
  module Api
    module V3
      module Admin
        # One product's quantity terms under a catalog — the grain the
        # agreement editor states them at, over rows stored per variant.
        class CatalogProductTermSerializer < V3::BaseSerializer
          typelize product_id: :string, product_name: 'string | null',
                   minimum_order_quantity: ['number | null'],
                   order_multiple: ['number | null'],
                   mixed: :boolean

          attribute :id do |term|
            term.product.prefixed_id
          end

          attribute :product_id do |term|
            term.product.prefixed_id
          end

          attribute :product_name do |term|
            term.product.name
          end

          attribute :minimum_order_quantity, &:minimum_order_quantity
          attribute :order_multiple, &:order_multiple

          # True when the product's variants carry different terms, so the
          # editor shows "mixed" rather than claiming one variant's pair is
          # the product's.
          attribute :mixed do |term|
            term.mixed?
          end
        end
      end
    end
  end
end
