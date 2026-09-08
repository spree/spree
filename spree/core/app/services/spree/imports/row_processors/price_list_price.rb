module Spree
  module Imports
    module RowProcessors
      # Writes one rung of one variant's ladder on the import's price list.
      #
      # The write goes through Spree::Prices::BulkUpsert, the same path the
      # bulk price editor uses, so a blank price means "remove this rung" in
      # the file exactly as it does in the editor, and the break cap is judged
      # by the same code. What the service does not check — the sign of an
      # amount, a currency the store does not trade in — is refused here
      # first, since the service trusts its callers.
      class PriceListPrice < Base
        def initialize(row, **)
          super
          @store = import.store
        end

        attr_reader :store

        # @return [Spree::Variant] the variant whose ladder the row changed —
        #   whether it wrote a rung or removed one, so the group job publishes
        #   the product's update either way
        def process!
          price_list = cached_lookup(:price_list_import_list) { import.price_list }
          raise ArgumentError, Spree.t(:price_list_import_no_price_list) if price_list.nil?

          variant = find_variant
          currency = currency_for(attributes['currency'])
          quantity = attributes['min_quantity'].to_s.strip.presence
          row = {
            variant_id: variant.id,
            currency: currency,
            price_list_id: price_list.id,
            min_quantity: quantity,
            amount: amount_for(attributes['price'], 'price')
          }
          # The service writes both amounts on every upsert, so a file without
          # the column would blank every compare-at price it touched; a rung
          # keeps its own until a mapped column says otherwise.
          row[:compare_at_amount] = if mapped?('compare_at_price')
                                      amount_for(attributes['compare_at_price'], 'compare_at_price')
                                    else
                                      stored_compare_at(price_list, variant, currency, (quantity || 1).to_i)
                                    end

          result = Spree::Prices::BulkUpsert.call(rows: [row])
          raise ArgumentError, failure_message(result) unless result.success?

          remember_compare_at(variant, currency, (quantity || 1).to_i, row)
          variant
        end

        private

        # The store's own variants only, and exactly one of them: a SKU is
        # unique per seller, not per store, so two sellers' listings can share
        # one and the row cannot say which it meant. Cached per SKU, since a
        # group is one SKU's rows and every rung would otherwise repeat the join.
        def find_variant
          sku = attributes['sku'].to_s.strip
          raise ArgumentError, Spree.t(:price_list_import_sku_required) if sku.blank?

          variants = cached_lookup(:price_list_import_variant, sku.downcase) do
            # Case-insensitive, as the product import matches SKUs and as the
            # uniqueness validation compares them.
            store.variants.where(Spree::Variant.arel_table[:sku].lower.eq(sku.downcase)).limit(2).to_a
          end
          raise ArgumentError, Spree.t(:price_list_import_unknown_sku, sku: sku) if variants.empty?
          raise ArgumentError, Spree.t(:price_list_import_ambiguous_sku, sku: sku) if variants.many?

          variants.first
        end

        # Blank means the store's default currency; anything else has to be
        # one the store trades in, or the row would price the variant in a
        # currency no shopper can be shown.
        def currency_for(value)
          currency = value.to_s.strip.upcase.presence || store.default_currency
          return currency if supported_currencies.include?(currency)

          raise ArgumentError, Spree.t(:price_list_import_unsupported_currency, currency: currency)
        end

        def supported_currencies
          cached_lookup(:price_list_import_currencies) { store.supported_currencies_list.map(&:iso_code) }
        end

        # Digits with an optional dot — the shape the export writes and the one
        # figure that reads the same under every locale. A blank stays blank
        # (the service reads it as "remove"). Not the locale-aware parser: it
        # answers 0 for text it cannot read, and under a comma-decimal locale
        # it would read "16.50" as 1650.
        AMOUNT_FORMAT = /\A\d+(\.\d+)?\z/

        def amount_for(value, column)
          text = value.to_s.strip
          return nil if text.blank?
          raise ArgumentError, Spree.t(:price_list_import_invalid_amount, column: column, value: text) unless text.match?(AMOUNT_FORMAT)

          BigDecimal(text)
        end

        def mapped?(field)
          cached_lookup(:price_list_import_mapped_fields) { import.mappings.mapped.pluck(:schema_field) }.include?(field)
        end

        # The compare-at a rung holds now, read once per variant for the whole
        # group and kept true by `remember_compare_at` as the group's rows
        # write and remove rungs.
        def stored_compare_at(price_list, variant, currency, quantity)
          compare_at_rungs(price_list, variant)[[currency, quantity]]
        end

        def compare_at_rungs(price_list, variant)
          cached_lookup(:price_list_import_compare_at, variant.id) do
            price_list.prices.where(variant_id: variant.id)
                      .pluck(:currency, :min_quantity, :compare_at_amount)
                      .to_h { |rung_currency, rung_quantity, compare_at| [[rung_currency, rung_quantity], compare_at] }
          end
        end

        def remember_compare_at(variant, currency, quantity, row)
          rungs = import.row_lookup_cache[[:price_list_import_compare_at, variant.id]]
          return if rungs.nil?

          if row[:amount].nil?
            rungs.delete([currency, quantity])
          else
            rungs[[currency, quantity]] = row[:compare_at_amount]
          end
        end

        def failure_message(result)
          value = result.error&.value
          value = {} unless value.is_a?(Hash)

          if value[:over_cap].present?
            Spree.t(:price_list_import_too_many_breaks, count: Spree::Price::MAXIMUM_BREAKS_PER_VARIANT)
          elsif value[:invalid_quantities].present?
            Spree.t(:price_list_import_invalid_quantity, value: attributes['min_quantity'])
          else
            result.error.to_s.presence || Spree.t(:price_list_import_failed)
          end
        end
      end
    end
  end
end
