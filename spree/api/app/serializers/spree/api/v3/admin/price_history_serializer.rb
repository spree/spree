# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class PriceHistorySerializer < V3::PriceHistorySerializer
          typelize variant_id: :string,
                   price_id: :string,
                   compare_at_amount: [:string, nullable: true],
                   created_at: :string

          attribute :variant_id do |price_history|
            price_history.variant.prefixed_id
          end

          attribute :price_id do |price_history|
            price_history.price.prefixed_id
          end

          attributes :compare_at_amount, created_at: :iso8601
        end
      end
    end
  end
end
