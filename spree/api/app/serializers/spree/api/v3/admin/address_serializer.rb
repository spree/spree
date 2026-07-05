module Spree
  module Api
    module V3
      module Admin
        class AddressSerializer < V3::AddressSerializer
          typelize label: [:string, nullable: true],
                   customer_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :label, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :customer_id do |address|
            address.user&.prefixed_id
          end
        end
      end
    end
  end
end
