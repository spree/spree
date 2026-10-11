module Spree
  module Api
    module V3
      # Admin and Seller writes take money and rates as canonical decimal
      # strings only ("19.99", "0.23"): a JSON number, localized text or more
      # decimals than the field holds is answered with `invalid_money_format`
      # before anything is written. A money field checks its currency's decimals
      # when the payload names the currency beside it, and four otherwise; unit
      # prices always allow four. Store API writes carry no amounts and are not
      # checked here.
      module StrictMoneyParams
        extend ActiveSupport::Concern

        MONEY_KEYS = %w[
          amount compare_at_amount cost cost_price price unit_cost refund_amount settled_amount
          minimum_payout_amount min_amount max_amount markup_flat
          amount_min amount_max first_item additional_item minimal_amount normal_amount discount_amount
          base_amount minimum_item_total maximum_item_total default_minimum_payout_amount
          preferred_default_minimum_payout_amount
        ].freeze

        UNIT_PRICE_KEYS = %w[price compare_at_amount cost_price unit_cost].freeze

        RATE_KEYS = %w[
          rate rate_percent percent flat_percent base_percent markup_percent percentage
          price_adjustment_percentage commission_tax_rate default_commission_tax_rate
          preferred_default_commission_tax_rate
        ].freeze

        # Values the merchant or a provider owns, stored as sent.
        OPAQUE_KEYS = %w[metadata custom_fields external_data].freeze

        included do
          before_action :refuse_noncanonical_decimals, if: -> { request.post? || request.patch? || request.put? }
        end

        private

        def refuse_noncanonical_decimals
          check_decimals(request.request_parameters, parent: nil, currency: nil)
        end

        def check_decimals(node, parent:, currency:)
          case node
          when Hash
            currency = node['currency'].presence || currency
            node.each do |key, value|
              next if OPAQUE_KEYS.include?(key)

              if scalar?(value) && MONEY_KEYS.include?(key)
                check_money(key, value, currency, UNIT_PRICE_KEYS.include?(key) || (key == 'amount' && parent == 'prices'))
              elsif scalar?(value) && RATE_KEYS.include?(key)
                check_rate(key, value)
              else
                check_decimals(value, parent: key, currency: currency)
              end
            end
          when Array
            node.each { |item| check_decimals(item, parent: parent, currency: currency) }
          end
        end

        def check_money(key, value, currency, unit_price)
          return if blank_value?(value)

          Spree::Money::Rounding.parse_canonical(value, currency.presence, unit_price: unit_price)
        rescue Spree::Money::InvalidFormat => error
          raise Spree::Money::InvalidFormat.new(error.message, field: key.to_sym)
        end

        def check_rate(key, value)
          return if blank_value?(value)

          Spree::Money::Rounding.parse_canonical_decimal(value)
        rescue Spree::Money::InvalidFormat => error
          raise Spree::Money::InvalidFormat.new(error.message, field: key.to_sym)
        end

        def scalar?(value)
          !value.is_a?(Hash) && !value.is_a?(Array)
        end

        def blank_value?(value)
          value.nil? || (value.is_a?(String) && value.strip.empty?)
        end
      end
    end
  end
end
