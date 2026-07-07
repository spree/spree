module Spree
  module Api
    module V3
      module Admin
        # Canonicalizes money attributes on permitted params before they
        # reach a model setter that delegates to
        # `Spree::LocalizedNumber.parse` (`Spree::Price#amount=`,
        # `Spree::Price#compare_at_amount=`, `Spree::Variant#cost_price=`) —
        # a no-op on non-String input. Converting to `BigDecimal` here means
        # the locale-aware parser is never invoked for Admin API v3 writes,
        # so the same payload always persists the same amount regardless of
        # the request's I18n locale.
        #
        # Include in any controller whose `permitted_params` carries a bare
        # money attribute and/or nested `prices:` / `variants: [{ prices:
        # [...] }]` rows destined for a model setter (as opposed to
        # `Spree::Prices::BulkUpsert`, which parses canonically on its own).
        module CanonicalMoneyParams
          extend ActiveSupport::Concern

          MONEY_ATTRIBUTES = %i[amount compare_at_amount cost_price].freeze

          private

          def canonicalize_money_attrs!(attrs)
            return attrs unless attrs.respond_to?(:key?)

            MONEY_ATTRIBUTES.each do |key|
              attrs[key] = Spree::CanonicalNumber.parse(attrs[key]) if attrs.key?(key)
            end

            %i[prices variants].each do |key|
              Array(attrs[key]).each { |row| canonicalize_money_attrs!(row) } if attrs[key]
            end

            attrs
          end
        end
      end
    end
  end
end
