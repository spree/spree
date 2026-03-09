module Spree
  module Api
    module V3
      module Admin
        class AddressSerializer < V3::AddressSerializer
          typelize label: [:string, nullable: true],
                   user_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown> | null'

          attributes :label,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :user_id do |address|
            address.user&.prefixed_id
          end

          attribute :metadata do |address|
            address.metadata.presence
          end
        end
      end
    end
  end
end
