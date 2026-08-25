module Spree
  module Api
    module V3
      module Store
        module Companies
          # The pending invitations into one node, visible to its members.
          # Revocation is addressed directly by invitation id.
          class InvitationsController < BaseController
            protected

            def model_class
              Spree::CompanyInvitation
            end

            def serializer_class
              Spree.api.company_invitation_serializer
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
