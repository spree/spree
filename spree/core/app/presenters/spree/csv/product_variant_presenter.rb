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
        'seller_name',
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
        'stock_location',
        'tax_category',
        'product_type',
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

      # @param default_stock_location [Spree::StockLocation, nil] where the full row's
      #   inventory columns read from, blank when the variant has no stock
      #   there; the store's default when nil
      # @param stock_level [Spree::StockLevel, nil] turns the row into a
      #   stock-only row for that level's location
      def initialize(product, variant, index = 0, properties = [], categories = [], store = nil, custom_fields = [], currency = nil,
                     default_stock_location: nil, stock_level: nil)
        @product = product
        @variant = variant
        @index = index
        @properties = properties
        @categories = categories
        @store = store || product.store
        @currency = currency || @store.default_currency
        @price_only = @currency != @store.default_currency
        @custom_fields = custom_fields
        @default_stock_location = default_stock_location
        @stock_level = stock_level
      end

      attr_accessor :product, :variant, :index, :properties, :categories, :store, :currency, :price_only, :custom_fields,
                    :default_stock_location, :stock_level

      ##
      # Generates an array representing a CSV row of product variant data.
      #
      # For the primary variant row (when the index is zero), product-level details such as name,
      # slug, status, seller name, description, meta tags, and tag/label lists are included.
      # In all cases, variant-specific attributes (e.g., id, SKU, pricing, dimensions, weight,
      # availability dates, inventory count, shipping category, tax category, image URLs via original_url,
      # and the first three option types and corresponding option values) are appended.
      # Additionally, when the index is zero, associated categories and properties are added.
      #
      # @return [Array] An array containing the combined product and variant CSV data.
      def call
        return price_only_row if price_only
        return stock_only_row if stock_level

        csv = [
          product.id,
          variant.sku,
          index.zero? ? product.name : nil,
          product.slug,
          index.zero? ? product.status : nil,
          index.zero? ? product.try(:seller_name) : nil,
          index.zero? ? product.description : nil,
          index.zero? ? product.meta_title : nil,
          index.zero? ? product.meta_description : nil,
          index.zero? ? product.meta_keywords : nil,
          index.zero? ? product.tag_list.to_s : nil,
          index.zero? ? product.label_list.to_s : nil,
          unit_price(variant.amount_in(currency) || 0),
          unit_price(variant.compare_at_amount_in(currency) || 0),
          currency,
          decimal(variant.width),
          decimal(variant.height),
          decimal(variant.depth),
          # The stored columns, not the resolved readers: importing this file
          # into a store on another unit system must not silently write this
          # store's units onto every variant.
          variant[:dimensions_unit],
          decimal(variant.weight),
          variant[:weight_unit],
          publication_available_on&.strftime('%Y-%m-%d %H:%M:%S'),
          (variant.discontinue_on || publication_discontinue_on)&.strftime('%Y-%m-%d %H:%M:%S'),
          variant.track_inventory?,
          # The shelf count at the one location the import writes this row
          # back to, not what is left to sell: that would drop every unit held
          # by a cart or promised to an order on each round trip.
          variant.should_track_inventory? ? default_stock_level&.count_on_hand : '∞',
          default_stock_level&.backorderable,
          nil,
          variant.tax_category&.name,
          product.product_type&.name,
          spree_image_url(variant.images[0], image_url_options),
          spree_image_url(variant.images[1], image_url_options),
          spree_image_url(variant.images[2], image_url_options),
          option_type(0)&.label,
          option_value(option_type(0)),
          option_type(1)&.label,
          option_value(option_type(1)),
          option_type(2)&.label,
          option_value(option_type(2))
        ]

        if index.zero?
          csv += categories
          csv += properties
          csv += custom_fields
        end

        csv
      end

      def option_type(index)
        product.option_types[index]
      end

      def option_value(option_type)
        variant.option_values.find { |ov| ov.option_type == option_type }&.label
      end

      private

      def unit_price(amount)
        Spree::Money::Rounding.format(amount, currency, unit_price: true)
      end

      # "1.5", never Ruby's "0.15e1", which the import refuses.
      def decimal(value)
        Spree::Money::Rounding.format_decimal(value)
      end

      # Default-channel publication for the export's store. 5.5 transitional:
      # fall back to the legacy Product columns when the publication dates are
      # NULL (pre-backfill). 6.0 drops the Product-column fallback.
      def default_publication
        return @default_publication if defined?(@default_publication)

        channel_id = store&.default_channel&.id
        @default_publication = channel_id && product.product_publications.find do |p|
          p.store_id == store.id && p.channel_id == channel_id
        end
      end

      def publication_available_on
        default_publication&.published_at || product.available_on
      end

      def publication_discontinue_on
        default_publication&.unpublished_at || product.discontinue_on
      end

      def price_only_row
        csv = Array.new(CSV_HEADERS.size)
        csv[CSV_HEADERS.index('sku')] = variant.sku
        csv[CSV_HEADERS.index('slug')] = product.slug
        csv[CSV_HEADERS.index('price')] = unit_price(variant.amount_in(currency))
        csv[CSV_HEADERS.index('compare_at_price')] = unit_price(variant.compare_at_amount_in(currency))
        csv[CSV_HEADERS.index('currency')] = currency
        csv
      end

      def stock_only_row
        csv = Array.new(CSV_HEADERS.size)
        csv[CSV_HEADERS.index('sku')] = variant.sku
        csv[CSV_HEADERS.index('slug')] = product.slug
        csv[CSV_HEADERS.index('inventory_count')] = stock_level.count_on_hand
        csv[CSV_HEADERS.index('inventory_backorderable')] = stock_level.backorderable
        csv[CSV_HEADERS.index('stock_location')] = stock_level.stock_location.name
        csv
      end

      def default_stock_level
        return @default_stock_level if defined?(@default_stock_level)

        location = default_stock_location || store.default_stock_location
        @default_stock_level = variant.stock_levels.find { |level| level.stock_location_id == location.id }
      end

      def image_url_options
        { variant: :xlarge }
      end
    end
  end
end
