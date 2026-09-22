module Spree
  module Imports
    module RowProcessors
      # One line of a purchase order. The first row carrying a reference opens
      # a draft for it through the same workflow the screen uses; every later
      # row with that reference adds its line. Suppliers, warehouses and SKUs
      # are named, not created: a typo must fail the row, not spawn a record.
      class PurchaseOrder < Base
        QUANTITY_FORMAT = /\A\d+\z/
        AMOUNT_FORMAT = /\A\d+(\.\d+)?\z/

        def initialize(row, **)
          super
          @store = import.store
        end

        attr_reader :store

        def process!
          reference = attributes['reference'].to_s.strip
          raise ArgumentError, Spree.t(:purchase_order_import_reference_required) if reference.blank?

          line = {
            variant: find_variant,
            quantity_ordered: quantity_for(attributes['quantity']),
            unit_cost: amount_for(attributes['unit_cost'])
          }

          cache = import.row_lookup_cache
          key = [:purchase_order_import_order, reference]
          if cache.key?(key)
            add_line(cache[key], line)
          else
            cache[key] = open_draft(reference, line)
          end
        end

        private

        def open_draft(reference, line)
          result = Spree::PurchaseOrders::Create.call(
            store: store,
            supplier: find_supplier,
            destination_location: find_destination,
            items: [line],
            currency: currency_for(attributes['currency']),
            expected_at: date_for(attributes['expected_at'], 'expected_at'),
            cancel_by: date_for(attributes['cancel_by'], 'cancel_by'),
            reference: reference,
            notes: attributes['notes'].to_s.strip.presence,
            created_by: import.user
          )
          raise ArgumentError, failure_message(result) unless result.success?

          result.value
        end

        # The update replaces the lines wholesale, so the ones already on the
        # draft go back with the new one. A SKU repeated under one reference
        # is one line with the quantities added, the way a picker would total
        # two cartons of the same thing.
        def add_line(purchase_order, line)
          lines = purchase_order.items.map do |item|
            { variant: item.variant, quantity_ordered: item.quantity_ordered, unit_cost: item.unit_cost }
          end
          existing = lines.find { |entry| entry[:variant].id == line[:variant].id }
          if existing
            existing[:quantity_ordered] += line[:quantity_ordered]
          else
            lines << line
          end

          result = Spree::PurchaseOrders::Update.call(purchase_order: purchase_order, items: lines)
          raise ArgumentError, failure_message(result) unless result.success?

          result.value
        end

        def find_supplier
          name = attributes['supplier'].to_s.strip
          raise ArgumentError, Spree.t(:purchase_order_import_supplier_required) if name.blank?

          cached_lookup(:purchase_order_import_supplier, name.downcase) do
            store.suppliers.find_by(Spree::Supplier.arel_table[:name].lower.eq(name.downcase))
          end || raise(ArgumentError, Spree.t(:purchase_order_import_unknown_supplier, name: name))
        end

        def find_destination
          name = attributes['destination'].to_s.strip
          raise ArgumentError, Spree.t(:purchase_order_import_destination_required) if name.blank?

          cached_lookup(:purchase_order_import_destination, name.downcase) do
            store.stock_locations.find_by(Spree::StockLocation.arel_table[:name].lower.eq(name.downcase))
          end || raise(ArgumentError, Spree.t(:purchase_order_import_unknown_destination, name: name))
        end

        def find_variant
          sku = attributes['sku'].to_s.strip
          raise ArgumentError, Spree.t(:purchase_order_import_sku_required) if sku.blank?

          variants = cached_lookup(:purchase_order_import_variant, sku.downcase) do
            store.variants.where(Spree::Variant.arel_table[:sku].lower.eq(sku.downcase)).limit(2).to_a
          end
          raise ArgumentError, Spree.t(:purchase_order_import_unknown_sku, sku: sku) if variants.empty?
          raise ArgumentError, Spree.t(:purchase_order_import_ambiguous_sku, sku: sku) if variants.many?

          variants.first
        end

        def quantity_for(value)
          text = value.to_s.strip
          unless text.match?(QUANTITY_FORMAT) && text.to_i.positive?
            raise ArgumentError, Spree.t(:purchase_order_import_invalid_quantity, value: text)
          end

          text.to_i
        end

        def amount_for(value)
          text = value.to_s.strip
          raise ArgumentError, Spree.t(:purchase_order_import_invalid_cost, value: text) unless text.match?(AMOUNT_FORMAT)

          BigDecimal(text)
        end

        def currency_for(value)
          currency = value.to_s.strip.upcase.presence || store.default_currency
          return currency if supported_currencies.include?(currency)

          raise ArgumentError, Spree.t(:purchase_order_import_unsupported_currency, currency: currency)
        end

        def supported_currencies
          cached_lookup(:purchase_order_import_currencies) { store.supported_currencies_list.map(&:iso_code) }
        end

        # A complete date only: `Date.parse` would take "March" and guess the
        # rest, and a guessed delivery date is worse than none.
        def date_for(value, column)
          text = value.to_s.strip
          return nil if text.blank?

          Date.iso8601(text)
        rescue Date::Error
          raise ArgumentError, Spree.t(:purchase_order_import_invalid_date, column: column, value: text)
        end

        def failure_message(result)
          error = result.error
          return error.full_messages.to_sentence if error.respond_to?(:full_messages)

          error.to_s.presence || Spree.t(:purchase_order_import_failed)
        end
      end
    end
  end
end
