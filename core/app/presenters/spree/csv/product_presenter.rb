require 'csv'

module Spree
  module CSV
    class ProductPresenter
      def initialize(product, properties = [], store = nil)
        @product = product
        @properties = properties
        @store = store || product.stores.first
        @currency = @store.default_currency
      end

      attr_accessor :product, :properties, :store, :currency

      def call
        [
          product.id,
          product.try(:vendor_name),
          product.try(:brand_name),
          product.name,
          product.description&.html_safe,
          product.amount_in(currency).to_f,
          product.meta_title,
          product.meta_description,
          product.meta_keywords,
          product.tag_list.to_s,
          product.label_list.to_s,
          product.width,
          product.height,
          product.depth,
          product.weight,
          product.available_on&.strftime('%Y-%m-%d %H:%M:%S'),
          product.discontinue_on&.strftime('%Y-%m-%d %H:%M:%S'),
          product.status,
          *map_categories(product),
          product.total_on_hand == BigDecimal::INFINITY ? '∞' : product.total_on_hand,
          *present_properties
        ]
      end

      private

      def map_categories(product)
        categories = [nil, nil, nil]

        product.taxons.reorder(depth: :desc).first(3).pluck(:pretty_name).each_with_index do |category_name, index|
          categories[index] = category_name
        end

        categories
      end

      def present_properties
        properties.flat_map do |property|
          [
            property.name,
            product.property(property.name)
          ]
        end
      end
    end
  end
end
