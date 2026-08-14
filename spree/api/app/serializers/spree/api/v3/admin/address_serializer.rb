module Spree
  module Api
    module V3
      module Admin
        class AddressSerializer < V3::AddressSerializer
          typelize label: [:string, nullable: true],
                   customer_id: [:string, nullable: true],
                   state_code: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          # The Admin API speaks the canonical name; the store contract
          # shipped state_abbr and keeps it.
          remove_attributes :state_abbr
          attributes :state_code

          attributes :label, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :customer_id do |address|
            address.customer&.prefixed_id
          end
        end
      end
    end
  end
end
