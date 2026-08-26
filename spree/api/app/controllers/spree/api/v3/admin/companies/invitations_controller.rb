module Spree
  module Api
    module V3
      module Admin
        module Companies
          # The pending invitations into one node. Revocation is addressed
          # directly by invitation id (CompanyInvitationsController).
          class InvitationsController < BaseController
            before_action :authorize_parent_access!

            # DELETE /api/v3/admin/companies/:company_id/invitations/:id
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
              Spree.api.admin_company_invitation_serializer
            end

            # Pending only, and narrowed before pagination: a page of spent
            # invitations would otherwise push live ones out of the first
            # page and make the row count describe the wrong set. Spent and
            # revoked rows are history, not a work list.
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
