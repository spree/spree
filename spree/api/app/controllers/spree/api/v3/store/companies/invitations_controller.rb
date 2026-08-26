module Spree
  module Api
    module V3
      module Store
        module Companies
          # The pending invitations into one node, visible to its members.
          # Revocation is addressed directly by invitation id.
          class InvitationsController < BaseController
            # DELETE /api/v3/store/companies/:company_id/invitations/:id
            #
            # Revokes rather than erases: a spent token keeps refusing.
            def destroy
              if @resource.revoke!
                head :no_content
              else
                render_error(
                  code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                  message: Spree.t('company_invitations.not_pending'),
                  status: :unprocessable_content
                )
              end
            end

            protected

            def model_class
              Spree::CompanyInvitation
            end

            def serializer_class
              Spree.api.company_invitation_serializer
            end

            # The listing shows live invitations only, so spent rows cannot
            # push pending ones off the first page. Addressing one by id still
            # finds it, so revoking an already-spent invitation answers "not
            # pending" rather than "no such invitation".
            def scope
              action_name == 'index' ? @parent.invitations.pending : @parent.invitations
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
