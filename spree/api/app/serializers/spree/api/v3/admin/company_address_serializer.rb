module Spree
  module Api
    module V3
      module Admin
        # An entry in a company node's address book. Admin-only shape; the
        # storefront self-service surface serializes the same record through
        # its own class.
        class CompanyAddressSerializer < V3::BaseSerializer
          typelize label: [:string, nullable: true], company_id: :string,
                   default_billing: :boolean, default_shipping: :boolean

          attributes :label, :default_billing, :default_shipping,
                     created_at: :iso8601, updated_at: :iso8601

          # An entry always belongs to a company, so this is never null.
          attribute :company_id do |entry|
            entry.company.prefixed_id
          end

          one :address, resource: proc { Spree.api.admin_address_serializer }
        end
      end
    end
  end
end
