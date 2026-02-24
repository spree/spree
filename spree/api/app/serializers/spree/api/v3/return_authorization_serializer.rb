# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ReturnAuthorizationSerializer < BaseSerializer
        typelize number: :string, state: :string,
                 order_id: [:string, nullable: true], stock_location_id: [:string, nullable: true],
                 return_authorization_reason_id: [:string, nullable: true]

        attributes :number, created_at: :iso8601, updated_at: :iso8601

        attribute :state do |return_authorization|
          return_authorization.state.to_s
        end

        attribute :order_id do |return_authorization|
          return_authorization.order&.prefixed_id
        end

        attribute :stock_location_id do |return_authorization|
          return_authorization.stock_location&.prefixed_id
        end

        attribute :return_authorization_reason_id do |return_authorization|
          return_authorization.reason&.prefixed_id
        end
      end
    end
  end
end
