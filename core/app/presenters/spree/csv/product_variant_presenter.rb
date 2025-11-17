module Spree
  module CSV
    class ProductVariantPresenter
      include Spree::ImagesHelper

      CSV_HEADERS = [
        'product_id',
        'sku',
        'name',
        'slug',
        'status',
        'vendor_name',
        'brand_name',
        'description',
        'meta_title',
        'meta_description',
        'meta_keywords',
        'tags',
        'labels',
        'price',
        'compare_at_price',
        'currency',
        'width',
        'height',
        'depth',
        'dimensions_unit',
        'weight',
        'weight_unit',
        'available_on',
        'discontinue_on',
        'track_inventory',
        'inventory_count',
        'inventory_backorderable',
        'tax_category',
        'shipping_category',
        'image1_src',
        'image2_src',
        'image3_src',
        'option1_name',
        'option1_value',
        'option2_name',
        'option2_value',
        'option3_name',
        'option3_value',
        'category1',
        'category2',
        'category3',
      ].freeze

      def initialize(product, variant, index = 0, properties = [], taxons = [], store = nil, metafields = [])
        @product = product
        @variant = variant
        @index = index
        @properties = properties
        @taxons = taxons
        @store = store || product.stores.first
        @currency = @store.default_currency
        @metafields = metafields
      end

      attr_accessor :product, :variant, :index, :properties, :taxons, :store, :currency, :metafields

      ##
      # Generates an array representing a CSV row of product variant data.
      #
      # For the primary variant row (when the index is zero), product-level details such as name,
      # slug, status, vendor and brand names, description, meta tags, and tag/label lists are included.
      # In all cases, variant-specific attributes (e.g., id, SKU, pricing, dimensions, weight,
      # availability dates, inventory count, shipping category, tax category, image URLs via original_url,
      # and the first three option types and corresponding option values) are appended.
      # Additionally, when the index is zero, associated taxons and properties are added.
      #
      # @return [Array] An array containing the combined product and variant CSV data.
      def call
        total_on_hand = variant.total_on_hand

        csv = [
          product.id,
          variant.sku,
          index.zero? ? product.name : nil,
          product.slug,
          index.zero? ? product.status : nil,
          index.zero? ? product.try(:vendor_name) : nil,
          index.zero? ? product.try(:brand_name) : nil,
          index.zero? ? product.description&.html_safe : nil,
          index.zero? ? product.meta_title : nil,
          index.zero? ? product.meta_description : nil,
          index.zero? ? product.meta_keywords : nil,
          index.zero? ? product.tag_list.to_s : nil,
          index.zero? ? product.label_list.to_s : nil,
          variant.amount_in(currency).to_f,
          variant.compare_at_amount_in(currency).to_f,
          currency,
          variant.width,
          variant.height,
          variant.depth,
          variant.dimensions_unit,
          variant.weight,
          variant.weight_unit,
          variant.available_on&.strftime('%Y-%m-%d %H:%M:%S'),
          (variant.discontinue_on || product.discontinue_on)&.strftime('%Y-%m-%d %H:%M:%S'),
          variant.track_inventory?,
          total_on_hand == BigDecimal::INFINITY ? '∞' : total_on_hand,
          variant.backorderable?,
          variant.tax_category&.name,
          product.shipping_category&.name,
          spree_image_url(variant.images[0], image_url_options),
          spree_image_url(variant.images[1], image_url_options),
          spree_image_url(variant.images[2], image_url_options),
          index.positive? ? option_type(0)&.presentation : nil,
          index.positive? ? option_value(option_type(0)) : nil,
          index.positive? ? option_type(1)&.presentation : nil,
          index.positive? ? option_value(option_type(1)) : nil,
          index.positive? ? option_type(2)&.presentation : nil,
          index.positive? ? option_value(option_type(2)) : nil
        ]

        if index.zero?
          csv += taxons
          csv += properties
          csv += metafields
        end

        csv
      end

      def option_type(index)
        product.option_types[index]
      end

      def option_value(option_type)
        variant.option_values.find { |ov| ov.option_type == option_type }&.presentation
      end

      private

      def image_url_options
        {
          width: 1000,
          height: 1000
        }
      end
    end
  end
end
