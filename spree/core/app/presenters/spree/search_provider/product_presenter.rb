module Spree
  module SearchProvider
    class ProductPresenter
      attr_reader :product, :store

      def initialize(product, store)
        @product = product
        @store = store
      end

      # Returns an array of documents — one per market × locale combination.
      # Each document has flat name, description, price fields (no dynamic suffixes).
      def call
        documents = []

        market_locale_pairs.each do |market, locale|
          # Skip if product has no price in this currency
          next unless lowest_price(market.currency)

          Mobility.with_locale(locale) do
            documents << build_document(locale, market.currency, default_locale)
          end
        end

        # Fallback for stores without markets (legacy/test)
        if documents.empty?
          fallback_currency = store.default_market&.currency || store.supported_currencies_list.first&.iso_code
          if fallback_currency && lowest_price(fallback_currency)
            documents << build_document(default_locale, fallback_currency, default_locale)
          end
        end

        documents
      end

      private

      def build_document(locale, currency, fallback_locale)
        {
          # Composite ID: product + locale + currency (Meilisearch primary key)
          id: "#{product.prefixed_id}_#{locale}_#{currency}",
          product_id: product.prefixed_id,
          locale: locale.to_s,
          currency: currency,
          # Translated fields — with fallback to default locale
          name: translated(product, :name, fallback_locale),
          description: translated(product, :description, fallback_locale),
          slug: translated(product, :slug, fallback_locale),
          # Price in this currency
          price: lowest_price(currency)&.to_f,
          compare_at_price: compare_at_price(currency)&.to_f,
          # Non-locale/currency fields
          status: product.status,
          sku: product.sku,
          in_stock: product.in_stock?,
          store_ids: cached_store_ids,
          discontinue_on: product.discontinue_on&.to_i || 0,
          category_ids: category_ids_with_ancestors,
          category_names: product.taxons.map { |t| translated(t, :name, fallback_locale) },
          option_type_ids: product.option_types.map(&:prefixed_id),
          option_type_names: product.option_types.map { |ot| translated(ot, :presentation, fallback_locale) },
          option_value_ids: variant_option_value_ids,
          option_values: variant_option_values_data.map { |ov| translated(ov, :presentation, fallback_locale) }.uniq,
          tags: product.tag_list || [],
          thumbnail_url: product.primary_media&.url(:large),
          units_sold_count: cached_units_sold_count,
          available_on: product.available_on&.iso8601,
          created_at: product.created_at&.iso8601,
          updated_at: product.updated_at&.iso8601
        }
      end

      # Returns all market × locale pairs for this store
      def market_locale_pairs
        @market_locale_pairs ||= store.markets.flat_map do |market|
          market.supported_locales_list.map { |locale| [market, locale] }
        end
      end

      def default_locale
        @default_locale ||= store.default_market&.default_locale || I18n.default_locale.to_s
      end

      # Read a translated attribute with fallback to default locale.
      def translated(record, attribute, fallback_locale)
        value = record.send(attribute)
        return value if value.present?

        record.send(attribute, locale: fallback_locale.to_sym)
      rescue ArgumentError
        value
      end

      def lowest_price(currency)
        @prices_cache ||= {}
        @prices_cache[currency] = product.price_in(currency)&.amount unless @prices_cache.key?(currency)
        @prices_cache[currency]
      end

      def compare_at_price(currency)
        @compare_at_cache ||= {}
        @compare_at_cache[currency] = product.compare_at_amount_in(currency) unless @compare_at_cache.key?(currency)
        @compare_at_cache[currency]
      end

      # Include ancestor category IDs so filtering by a parent category
      # matches products classified under its descendants.
      def category_ids_with_ancestors
        @category_ids_with_ancestors ||= product.taxons.flat_map { |t|
          t.self_and_ancestors.map(&:prefixed_id)
        }.uniq
      end

      # Memoized — avoids N+1 when called per document
      def cached_store_ids
        @cached_store_ids ||= product.store_ids.map(&:to_s)
      end

      def cached_units_sold_count
        @cached_units_sold_count ||= product.store_products.detect { |sp| sp.store_id == store.id }&.units_sold_count || 0
      end

      def variant_option_value_ids
        variant_option_values_data.map(&:prefixed_id).uniq
      end

      # Use variants_including_master (matches reindex preload) instead of variants.includes
      def variant_option_values_data
        @variant_option_values_data ||= product.variants_including_master.flat_map(&:option_values).uniq
      end
    end
  end
end
