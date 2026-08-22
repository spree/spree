module Spree
  module Api
    module V3
      module Admin
        class CompanySerializer < V3::CompanySerializer
          include Concerns::ExternalReferencesAttribute

          typelize locations_count: :number, metadata: 'Record<string, unknown> | null'

          attributes :metadata, created_at: :iso8601, updated_at: :iso8601

          # Saves the dashboard a request per row just to say "3 branches".
          attribute :locations_count do |company|
            company.company_locations.size
          end

          many :company_locations,
               resource: proc { Spree.api.admin_company_location_serializer },
               if: proc { expand?('company_locations') }
        end
      end
    end
  end
end
