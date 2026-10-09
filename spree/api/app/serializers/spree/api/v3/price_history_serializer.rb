# frozen_string_literal: true

module Spree
  module Api
    module V3
      class PriceHistorySerializer < BaseSerializer
        typelize display_amount: :string,
                 currency: :string,
                 recorded_at: :string

        attributes :currency

        money_attributes :amount, unit_price: true

        attributes :display_amount

        attribute :recorded_at do |price_history|
          price_history.recorded_at&.iso8601
        end
      end
    end
  end
end
