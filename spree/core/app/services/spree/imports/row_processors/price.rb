module Spree
  module Imports
    module RowProcessors
      # One row of a price feed: what a variant costs in a currency, optionally
      # on a named price list.
      #
      # A blank amount clears the price rather than writing zero — "we no
      # longer sell this here" and "this is free" are different statements.
      class Price < Base
        def process!
          variant = find_variant!
          currency = attributes['currency'].to_s.strip.upcase
          raise ArgumentError, 'Currency is required' if currency.blank?

          price = find_or_initialize_price(variant, currency)

          if attributes['amount'].to_s.strip.blank?
            price.destroy if price.persisted?
            return price
          end

          price.amount = decimal!('amount', attributes['amount'])
          price.compare_at_amount = decimal!('compare_at_amount', attributes['compare_at_amount'])
          price.save!
          price
        end

        private

        # Active Record casts an unparseable string to zero and stops at the
        # first non-numeric character, so "abc" imports as 0.00 and the
        # European "12,50" as 1250.00 — a hundredfold overcharge that no error
        # would ever report. A feed must say what it means.
        #
        # @return [BigDecimal, nil] nil when the column was blank
        # @raise [ArgumentError] when the value is not a number
        def decimal!(column, value)
          value = value.to_s.strip
          return nil if value.blank?

          begin
            BigDecimal(value)
          rescue ArgumentError, TypeError
            raise ArgumentError, "#{column} must be a number, got #{value.inspect}"
          end
        end

        def find_or_initialize_price(variant, currency)
          list = find_price_list
          variant.prices.find_or_initialize_by(currency: currency, price_list_id: list&.id)
        end

        def find_price_list
          name = attributes['price_list'].to_s.strip
          return if name.blank?

          list = cached_lookup(:price_list, name) { import.store.price_lists.find_by(name: name) }
          raise ArgumentError, "No price list named #{name}" if list.nil?

          list
        end
      end
    end
  end
end
