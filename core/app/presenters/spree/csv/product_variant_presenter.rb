module Spree
  module CSV
    class ProductVariantPresenter
      CSV_HEADERS = [
        'product_id',
        'sku',
        'barcode',
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
        'inventory_count',
        'inventory_backorderable',
        'tax_category',
        'digital'
      ].freeze

      def initialize(product, variant, index = 0, images_count = 3, options_count = 3, properties = [], taxons = [], store = nil)
        @product = product
        @variant = variant
        @index = index
        @images_count = images_count
        @options_count = options_count
        @properties = properties
        @taxons = taxons
        @store = store || product.stores.first
        @currency = @store.default_currency
      end

      attr_reader :product, :variant, :index, :images_count, :options_count, :properties, :taxons, :store, :currency

      ##
      # Generates an array representing a CSV row of product variant data.
      #
      # For the primary variant row (when the index is zero), product-level details such as name,
      # slug, status, vendor and brand names, description, meta tags, and tag/label lists are included.
      # In all cases, variant-specific attributes (e.g., id, SKU, pricing, dimensions, weight,
      # availability dates, inventory count, digital flag, tax category, image URLs via original_url,
      # and the first three option types and corresponding option values) are appended.
      # Additionally, when the index is zero, associated taxons and properties are added.
      #
      # @return [Array] An array containing the combined product and variant CSV data.
      def call
        images = variant.images.first(images_count)
        images.fill(nil, images.size...images_count)

        csv = [
          product.id,
          variant.sku,
          variant.barcode,
          index.zero? ? product.name : nil,
          index.zero? ? product.slug : nil,
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
          variant.compare_at_price&.to_f,
          currency,
          variant.width,
          variant.height,
          variant.depth,
          variant.dimensions_unit,
          variant.weight,
          variant.weight_unit,
          variant.available_on&.strftime('%Y-%m-%d %H:%M:%S'),
          variant.discontinue_on&.strftime('%Y-%m-%d %H:%M:%S'),
          variant.total_on_hand == BigDecimal::INFINITY ? '∞' : variant.total_on_hand,
          variant.backorderable?,
          variant.tax_category&.name,
          variant.digital?,
          *images.map { |image| image&.original_url },
          *options_count.times.map do |index|
            [
              option_type(index)&.name,
              option_value(option_type(index))
            ]
          end
        ].flatten

        if index.zero?
          csv += taxons
          csv += properties
        end

        csv
      end

      def option_type(index)
        product.option_types[index]
      end

      def option_value(option_type)
        variant.option_values.find { |ov| ov.option_type == option_type }&.name
      end
    end
  end
end
