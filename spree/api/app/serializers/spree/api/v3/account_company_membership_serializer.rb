module Spree
  module Api
    module V3
      # One of the signed-in buyer's own memberships, with the node it is
      # held on, so an account page offers its "buying for" choices from one
      # request.
      class AccountCompanyMembershipSerializer < CompanyMembershipSerializer
        one :company, resource: proc { Spree.api.company_serializer }
      end
    end
  end
end
