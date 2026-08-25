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

            # Pending only, and narrowed before pagination: a page of spent
            # invitations would otherwise push live ones out of the first
            # page and make the row count describe the wrong set. Spent and
            # revoked rows are history, not a work list.
            def scope
              @parent.invitations.pending
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
