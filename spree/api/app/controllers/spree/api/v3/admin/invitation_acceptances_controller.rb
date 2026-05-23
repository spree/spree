module Spree
  module Api
    module V3
      module Admin
        # Public invitation acceptance — mounted under `/api/v3/admin/auth/...`
        # so the issued refresh-token cookie's path matches `/auth/refresh`.
        class InvitationAcceptancesController < BaseController
          include Spree::Api::V3::Admin::AuthCookies

          skip_scope_check!
          skip_before_action :authenticate_admin!, only: [:lookup, :accept]

          rate_limit to: Spree::Api::Config[:rate_limit_login],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: [:lookup, :accept],
                     with: RATE_LIMIT_RESPONSE

          # GET /api/v3/admin/auth/invitations/:id/lookup?token=:token
          def lookup
            return unless load_invitation

            render json: Spree.api.admin_invitation_serializer.new(@invitation).serializable_hash
          end

          # POST /api/v3/admin/auth/invitations/:id/accept?token=:token
          # Body: { password?, password_confirmation?, first_name?, last_name? }
          def accept
            return unless load_invitation

            user = resolve_or_create_invitee(@invitation)
            return if performed?

            @invitation.invitee = user
            @invitation.accept!

            refresh_token = Spree::RefreshToken.create_for(user, request_env: request_env_for_token)
            set_refresh_cookie(refresh_token)
            render json: auth_response(user)
          rescue ActiveRecord::RecordInvalid => e
            render_validation_error(e.record.errors)
          end

          private

          # Token mismatch is treated identically to "not found" to avoid
          # leaking whether an ID exists.
          def load_invitation
            decoded_id = Spree::Invitation.decode_prefixed_id(params[:id])
            @invitation = Spree::Invitation.pending.not_expired.find_by(id: decoded_id, token: params[:token])

            unless @invitation
              render_error(
                code: ERROR_CODES[:record_not_found],
                message: 'Invitation not found, expired, or already accepted',
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
              code: ERROR_CODES[:authentication_failed],
              message: 'Invalid password',
              status: :unauthorized
            )
            nil
          end

          def create_new_invitee(invitation)
            if params[:password].blank?
              render_error(
                code: ERROR_CODES[:parameter_missing],
                message: 'Password is required to create your account',
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

          def auth_response(user)
            {
              token: generate_jwt(user, audience: JWT_AUDIENCE_ADMIN),
              user: admin_user_serializer.new(user, params: serializer_params).to_h
            }
          end

          def serializer_params
            {
              store: @invitation&.store || current_store,
              locale: current_locale,
              currency: current_currency,
              user: nil,
              includes: []
            }
          end

          def admin_user_serializer
            Spree.api.admin_admin_user_serializer
          end

          def request_env_for_token
            {
              ip_address: request.remote_ip,
              user_agent: request.user_agent&.truncate(255)
            }
          end

          def jwt_expiration
            Spree::Api::Config[:admin_jwt_expiration]
          end
        end
      end
    end
  end
end
