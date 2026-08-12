module Spree
  module Api
    module V3
      module Admin
        class CompanyContactSerializer < V3::BaseSerializer
          typelize role: :string, company_location_id: :string, customer_id: :string,
                   email: [:string, nullable: true]

          attributes :role, created_at: :iso8601, updated_at: :iso8601

          # Both associations are required, so these are never null and the
          # types above say so. Safe navigation here would have promised a null
          # the schema cannot produce.
          attribute :company_location_id do |contact|
            contact.company_location.prefixed_id
          end

          attribute :customer_id do |contact|
            contact.customer.prefixed_id
          end

          # The dashboard lists contacts by who they are, and would otherwise
          # need a customer request per row.
          attribute :email do |contact|
            contact.customer.email
          end
        end
      end
    end
  end
end
