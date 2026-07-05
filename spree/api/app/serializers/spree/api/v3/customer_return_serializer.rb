# frozen_string_literal: true

module Spree
  module Api
    module V3
      class CustomerReturnSerializer < BaseSerializer
        typelize number: :string, stock_location_id: [:string, nullable: true]

        attributes :number, created_at: :iso8601, updated_at: :iso8601

        attribute :stock_location_id do |customer_return|
          customer_return.stock_location&.prefixed_id
        end
      end
    end
  end
end
