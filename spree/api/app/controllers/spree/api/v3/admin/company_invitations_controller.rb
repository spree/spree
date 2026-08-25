module Spree
  module Api
    module V3
      module Admin
        # An invitation addressed directly. DELETE revokes rather than
        # destroys — the row is the record that an invite went out, and a
        # revoked token has to keep 404ing rather than becoming reissuable.
        class CompanyInvitationsController < ResourceController
          scoped_resource :customers

          # DELETE /api/v3/admin/company_invitations/:id
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

          def scope
            Spree::CompanyInvitation.where(company_id: current_store.companies.select(:id)).
              accessible_by(current_ability, ability_action_for_request)
          end
        end
      end
    end
  end
end
