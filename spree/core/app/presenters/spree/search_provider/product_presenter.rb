module Spree
  module SearchProvider
    class ProductPresenter
      attr_reader :product, :store

      def initialize(product, store)
        @product = product
        @store = store
      end

      # Returns an array of documents. For each (market × locale) the product is
      # priced in, one BASE document plus one MEMBERSHIP document per grouping the
      # product belongs to (each collection + each category ancestor-or-self),
      # carrying a scalar grouping_id + position so Meilisearch can sort a grouping
      # page by the merchant's hand-set position. Each document has flat name,
      # description, price fields (no dynamic suffixes).
      def call
        documents = []

        market_locale_pairs.each do |market, locale|
          # Skip if product has no price in this currency
          next unless lowest_price(market.currency)

          Mobility.with_locale(locale) do
            base = build_document(locale, market.currency, default_locale)
            documents << base
            documents.concat(membership_documents(base, locale, market.currency))
          end
        end

        # Fallback for stores without markets (legacy/test)
        if documents.empty?
          fallback_currency = store.default_market&.currency || store.supported_currencies_list.first&.iso_code
          if fallback_currency && lowest_price(fallback_currency)
            base = build_document(default_locale, fallback_currency, default_locale)
            documents << base
            documents.concat(membership_documents(base, default_locale, fallback_currency))
          end
        end

        documents
      end

      private

      # Build a document for a given locale and currency
      # @param locale [String] the locale to build the document for
      # @param currency [String] the currency to build the document for
      # @param fallback_locale [String] the fallback locale to use if the product has no translation for the given locale
      # @return [Hash] the document
      def build_document(locale, currency, fallback_locale)
        {
          # Composite ID: product + locale + currency
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
          # True when the product has an active pre-order variant, so a
          # scheduled (future-published) launch still surfaces in search.
          preorder: product.preorder?,
          store_ids: Array(product.store_id).map(&:to_s),
          channel_ids: channel_ids_for_store,
          discontinue_on: product.discontinue_on&.to_i || 0,
          category_ids: category_ids_with_ancestors,
          category_names: product.categories.map { |t| translated(t, :name, fallback_locale) },
          collection_ids: product.collections.map(&:prefixed_id),
          option_type_ids: product.option_types.map(&:prefixed_id),
          option_type_names: product.option_types.map { |ot| translated(ot, :presentation, fallback_locale) },
          option_value_ids: variant_option_value_ids,
          option_values: variant_option_values_data.map { |ov| translated(ov, :presentation, fallback_locale) }.uniq,
          tags: product.tag_list || [],
          units_sold_count: product.units_sold_count || 0,
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

      def channel_ids_for_store
        @channel_ids_for_store ||= product.product_publications
                                          .joins(:channel)
                                          .where(spree_channels: { store_id: store.id })
                                          .pluck(:channel_id)
                                          .map(&:to_s)
      end

      def category_ids_with_ancestors
        @category_ids_with_ancestors ||= product.categories.flat_map { |t|
          t.self_and_ancestors.map(&:prefixed_id)
        }.uniq
      end

      # One membership document per grouping (each collection + each category
      # ancestor-or-self) the product belongs to: the full base payload plus a
      # scalar grouping_id and position, with a distinct composite id. A manual-
      # sorted grouping page filters grouping_id and sorts by position.
      def membership_documents(base, locale, currency)
        grouping_positions.map do |grouping_id, position|
          base.merge(
            id: "#{product.prefixed_id}__#{grouping_id}_#{locale}_#{currency}",
            grouping_id: grouping_id,
            position: position
          )
        end
      end

      # { grouping_prefixed_id => position }, merged across collections (flat) and
      # categories (subtree-MIN). Prefixes (coll_/ctg_) keep the keys disjoint.
      def grouping_positions
        @grouping_positions ||= collection_positions.merge(category_positions)
      end

      # Flat: one entry per collection with the product's ProductCollection.position.
      def collection_positions
        @collection_positions ||= product.product_collections.pluck(:collection_id, :position).each_with_object({}) do |(cid, pos), acc|
          acc[prefixed_id_for(Spree::Collection, cid)] = pos
        end
      end

      # Subtree-MIN: a product under a category AND its descendants contributes its
      # position to every ancestor-or-self, folded to the minimum — mirrors the DB
      # provider's MIN(position)/GROUP BY and category_ids_with_ancestors.
      def category_positions
        @category_positions ||= begin
          positions_by_category_id = product.product_categories.pluck(:category_id, :position).to_h
          product.categories.each_with_object({}) do |category, acc|
            position = positions_by_category_id[category.id]
            category.self_and_ancestors.each do |ancestor|
              key = ancestor.prefixed_id
              acc[key] = [acc[key], position].compact.min
            end
          end
        end
      end

      # Encode a raw primary key into a model's prefixed id without loading the
      # record (mirrors Spree::PrefixedId#prefixed_id).
      def prefixed_id_for(klass, raw_id)
        "#{klass._prefix_id_prefix}_#{Spree::PrefixedId::SQIDS.encode([raw_id])}"
      end

      def variant_option_value_ids
        variant_option_values_data.map(&:prefixed_id).uniq
      end

      # Use variants (matches reindex preload) instead of variants.includes
      def variant_option_values_data
        @variant_option_values_data ||= product.variants.flat_map(&:option_values).uniq
      end
    end
  end
end
