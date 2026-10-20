# frozen_string_literal: true

module Spree
  module Api
    module V3
      class PriceHistorySerializer < BaseSerializer
        typelize display_amount: display_money_type(:display_amount, nullable: false),
                 currency: [:string, enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode'],
                 recorded_at: :string,
                 amount_in_cents: [:number, nullable: true, deprecated: 'Use `amount`. Removed in 6.1.']

        attributes :currency

        money_attributes :amount, unit_price: true

        attribute :amount_in_cents do |price_history|
          price_history.amount_in_cents unless params[:hide_prices]
        end

        attributes :display_amount

        attribute :recorded_at do |price_history|
          price_history.recorded_at&.iso8601
        end
      end
    end
  end
end
