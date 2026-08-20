module Spree
  module Api
    module V3
      module Seller
        # Public invitation acceptance for the seller panel — mounted under
        # `/api/v3/seller/auth/...` so the issued refresh-token cookie's path
        # matches `/auth/refresh`.
        #
        # Parallel to the admin controller rather than a subclass of it, per
        # Decision 10: what differs is the audience it issues and the
        # invitations it will touch, and both are the point.
        class InvitationAcceptancesController < Spree::Api::V3::BaseController
          include Spree::Api::V3::Seller::AuthCookies
          include Spree::Api::V3::JwtAuthentication

          # No `skip_scope_check!`: this extends the plain v3 base, which has
          # no authentication or scope gate to lift. The emailed token is the
          # only credential, exactly as on the admin twin.
          rate_limit to: Spree::Api::Config[:rate_limit_login],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: [:lookup, :accept],
                     with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_login]) }

          # GET /api/v3/seller/auth/invitations/:id/lookup?token=:token
          def lookup
            return unless load_invitation

            render json: Spree.api.seller_invitation_serializer.new(
              @invitation, params: { store: @invitation.store }
            ).serializable_hash
          end

          # POST /api/v3/seller/auth/invitations/:id/accept?token=:token
          # Body: { password?, password_confirmation?, first_name?, last_name? }
          def accept
            return unless load_invitation

            user = resolve_or_create_invitee(@invitation)
            return if performed?

            @invitation.invitee = user
            result = Spree.invitation_accept_workflow.call(invitation: @invitation)

            return render_service_error(result.error) unless result.success?

            set_refresh_cookie(
              Spree::RefreshToken.create_for(
                user,
                audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER,
                request_env: request_env_for_token
              )
            )

            render json: auth_response(user)
          end

          private

          # Only invitations onto a seller are acceptable here. A staff
          # invitation carries no seller membership, so accepting one through
          # this endpoint would mint a seller token for someone who runs no
          # seller — and it is indistinguishable from "not found" on purpose,
          # since the caller is unauthenticated either way.
          #
          # Token mismatch is treated identically to "not found" to avoid
          # leaking whether an ID exists.
          def load_invitation
            decoded_id = Spree::Invitation.decode_prefixed_id(params[:id])
            @invitation = Spree::Invitation.pending.not_expired.
                          where(resource_type: Spree::Seller.to_s).
                          find_by(id: decoded_id, token: params[:token])

            unless @invitation
              render_error(
                code: ErrorHandler::ERROR_CODES[:record_not_found],
                message: Spree.t(:invitation_not_acceptable),
                status: :not_found
              )
              return false
            end

            true
          end

          # Email match between the invitation and any existing account is
          # implicit: we look the user up by `invitation.email`, never by a
          # client-supplied email. The token is the credential.
          def resolve_or_create_invitee(invitation)
            existing = Spree.admin_user_class.find_by(email: invitation.email)
            return authenticate_existing(existing) if existing

            create_new_invitee(invitation)
          end

          def authenticate_existing(user)
            return user if user.valid_password?(params[:password].to_s)

            render_error(
              code: ErrorHandler::ERROR_CODES[:authentication_failed],
              message: Spree.t(:invalid_password),
              status: :unauthorized
            )
            nil
          end

          def create_new_invitee(invitation)
            if params[:password].blank?
              render_error(
                code: ErrorHandler::ERROR_CODES[:parameter_missing],
                message: Spree.t(:password_required_to_create_account),
                status: :unprocessable_content
              )
              return nil
            end

            Spree.admin_user_class.create!(signup_params(invitation))
          end

          def signup_params(invitation)
            params.permit(:password, :password_confirmation, :first_name, :last_name).
              merge(email: invitation.email)
          end

          # Same shape as the login response, so the panel can sign the new
          # member straight in rather than bouncing them to a login form.
          def auth_response(user)
            {
              token: generate_jwt(user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER),
              user: Spree.api.seller_team_member_serializer.new(
                user, params: { store: @invitation.store }
              ).to_h,
              sellers: serialized_sellers(user)
            }
          end

          def serialized_sellers(user)
            user.sellers.map { |seller| { id: seller.prefixed_id, name: seller.name, status: seller.status } }
          end

          def request_env_for_token
            { ip_address: request.remote_ip, user_agent: request.user_agent&.truncate(255) }
          end

          def jwt_expiration
            Spree::Api::Config[:admin_jwt_expiration]
          end
        end
      end
    end
  end
end
