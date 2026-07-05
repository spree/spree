# frozen_string_literal: true

module Spree
  module Api
    module V3
      class PriceHistorySerializer < BaseSerializer
        typelize amount: :string,
                 amount_in_cents: :number,
                 display_amount: :string,
                 currency: :string,
                 recorded_at: :string

        attributes :amount, :amount_in_cents, :currency

        attribute :display_amount do |price_history|
          price_history.display_amount
        end

        attribute :recorded_at do |price_history|
          price_history.recorded_at&.iso8601
        end
      end
    end
  end
end
