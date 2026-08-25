module Spree
  module Api
    module V3
      module Store
        # Invitations addressed directly. Two audiences share this
        # controller:
        #
        # - Members revoke by prefixed id (DELETE — authenticated, standing
        #   scoped).
        # - Invitees look up and accept by plaintext token (GET/POST —
        #   unauthenticated: the token from the invite email IS the
        #   credential, and the acceptance page must load before the invitee
        #   has an account, even on a login-gated store).
        class CompanyInvitationsController < ResourceController
          allow_guest_storefront_access!

          prepend_before_action :require_authentication!, only: [:destroy]

          # `show` is the token lookup, not a prefixed-id read — the standing
          # scope would 404 the unauthenticated invitee.
          skip_before_action :set_resource
          before_action :set_resource, only: [:destroy]

          # GET /api/v3/store/company_invitations/:token — what is being
          # joined. Expired and revoked tokens 404.
          def show
            invitation = find_by_token!

            render json: serialize_resource(invitation).merge(
              'company_name' => invitation.company.name,
              'store_name' => current_store.name
            )
          end

          # POST /api/v3/store/company_invitations/:token/accept
          #
          # Takes a registration payload (the account is created through the
          # customer-creation workflow, with the invited email), or an
          # authenticated request from a customer the invitation then binds
          # to. Returns the created membership.
          def accept
            invitation = find_by_token!

            result = Spree.company_invitation_accept_service.call(
              invitation: invitation,
              customer: current_user,
              customer_attributes: current_user ? nil : registration_params.to_h
            )

            if result.success?
              render json: Spree.api.company_membership_serializer.new(
                result.value, params: serializer_params
              ).to_h, status: :created
            elsif result.value.respond_to?(:errors) && result.value.errors.any?
              render_validation_error(result.value.errors)
            else
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t('company_invitations.not_pending'),
                status: :unprocessable_content
              )
            end
          end

          # DELETE /api/v3/store/company_invitations/:id — revoke, by any
          # member with standing.
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

          # For revocation: invitations of nodes the caller has standing over.
          def scope
            Spree::CompanyInvitation.where(
              company_id: storefront_access_policy.scope(current_store.companies).select(:id)
            )
          end

          private

          # Token lookup, scoped to the current store and to pending rows —
          # a spent, revoked or expired token does not exist.
          def find_by_token!
            Spree::CompanyInvitation.pending.
              where(company_id: current_store.companies.select(:id)).
              find_by!(token: params[:token] || params[:id])
          end

          def registration_params
            params.permit(:first_name, :last_name, :phone, :password, :password_confirmation)
          end
        end
      end
    end
  end
end
