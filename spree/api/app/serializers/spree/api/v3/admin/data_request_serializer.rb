module Spree
  module Api
    module V3
      module Admin
        # Admin API Data Request Serializer
        class DataRequestSerializer < V3::DataRequestSerializer
          typelize email: :string,
                   error_message: [:string, nullable: true],
                   customer_id: [:string, nullable: true],
                   requested_by_id: [:string, nullable: true]

          attributes :email, :error_message, created_at: :iso8601, updated_at: :iso8601

          attribute :customer_id do |data_request|
            data_request.customer&.prefixed_id
          end

          # Null when the subject asked for it themselves.
          attribute :requested_by_id do |data_request|
            data_request.requested_by&.prefixed_id
          end

          one :customer, resource: proc { Spree.api.admin_customer_serializer }, if: proc { expand?('customer') }
        end
      end
    end
  end
end
