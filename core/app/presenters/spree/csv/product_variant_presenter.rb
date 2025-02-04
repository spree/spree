module Spree
  module CSV
    class ProductVariantPresenter
      CSV_HEADERS = [
        'product_id',
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
        'variant_id',
        'variant_sku',
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
        'digital',
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

      def initialize(product, variant, index = 0, properties = [], taxons = [], store = nil)
        @product = product
        @variant = variant
        @index = index
        @properties = properties
        @taxons = taxons
        @store = store || product.stores.first
        @currency = @store.default_currency
      end

      attr_accessor :product, :variant, :index, :properties, :taxons, :store, :currency

      def call
        csv = [
          product.id,
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
          variant.id,
          variant.sku,
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
          variant.images[0]&.attachment&.url,
          variant.images[1]&.attachment&.url,
          variant.images[2]&.attachment&.url,
          option_type(0)&.name,
          option_value(option_type(0)),
          option_type(1)&.name,
          option_value(option_type(1)),
          option_type(2)&.name,
          option_value(option_type(2))
        ]

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
