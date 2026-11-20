module Spree
  module Api
    module V3
      class OrderChangeEventSerializer < BaseSerializer
        typelize status: :string,
                 order_id: :string,
                 return_id: [:string, nullable: true],
                 exchange_id: [:string, nullable: true],
                 claim_id: [:string, nullable: true],
                 requested_at: [:string, nullable: true],
                 confirmed_at: [:string, nullable: true],
                 canceled_at: [:string, nullable: true]

        attributes :status,
                   requested_at: :iso8601, confirmed_at: :iso8601, canceled_at: :iso8601,
                   created_at: :iso8601, updated_at: :iso8601

        prefixed_id_attributes :order, :return, :exchange, :claim
      end
    end
  end
end
