module Spree
  module Api
    module V3
      module Admin
        class CompanyMembershipSerializer < V3::CompanyMembershipSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          # The member as a customer, so a list can show their name, not only
          # the email.
          one :customer, resource: proc { Spree.api.admin_customer_serializer }, if: proc { expand?('customer') }
        end
      end
    end
  end
end
