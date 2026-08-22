module Spree
  module Api
    module V3
      module Admin
        # Admin-only: branches are back-office records with no storefront
        # surface, so there is no store serializer to extend. Deliberately not
        # sharing a parent with the company and contact serializers — Typelizer
        # emits one TS type per serializer, and an abstract one would reach the
        # admin SDK without any endpoint returning it.
        class CompanyLocationSerializer < V3::BaseSerializer
          include Concerns::ExternalReferencesAttribute

          typelize name: :string,
                   company_id: :string, contacts_count: :number,
                   metadata: 'Record<string, unknown> | null'

          attributes :name, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          # A branch always belongs to a company, so this is never null.
          attribute :company_id do |location|
            location.company.prefixed_id
          end

          attribute :contacts_count do |location|
            location.company_contacts.size
          end

          one :billing_address, resource: proc { Spree.api.admin_address_serializer }
          one :shipping_address, resource: proc { Spree.api.admin_address_serializer }

          many :company_contacts,
               resource: proc { Spree.api.admin_company_contact_serializer },
               if: proc { expand?('company_contacts') }
        end
      end
    end
  end
end
