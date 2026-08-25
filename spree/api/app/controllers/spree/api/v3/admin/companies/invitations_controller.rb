module Spree
  module Api
    module V3
      module Admin
        module Companies
          # The pending invitations into one node. Revocation is addressed
          # directly by invitation id (CompanyInvitationsController).
          class InvitationsController < BaseController
            before_action :authorize_parent_access!

            protected

            def model_class
              Spree::CompanyInvitation
            end

            def serializer_class
              Spree.api.admin_company_invitation_serializer
            end

            def scope
              @parent.invitations
            end

            def parent_association
              :invitations
            end
          end
        end
      end
    end
  end
end
