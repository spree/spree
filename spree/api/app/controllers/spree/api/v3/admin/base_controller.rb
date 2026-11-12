module Spree
  module Api
    module V3
      module Admin
        class BaseController < Spree::Api::V3::BaseController
          include Spree::Api::V3::Admin::StoreContext
          include Spree::Api::V3::AdminAuthentication

          # Must be registered before ScopedAuthorization so authenticate_admin!
          # resolves @current_api_key before authorize_api_key_scope! reads it —
          # otherwise the scope guard short-circuits on a nil key and never runs.
          before_action :authenticate_admin!

          include Spree::Api::V3::ScopedAuthorization
          include Spree::Api::V3::StrictMoneyParams
          include Spree::Api::V3::Admin::ValidationDetails
          include Spree::Api::V3::Admin::EmbedPermissions

          private

          # For endpoints about the signed-in staffer rather than the store
          # (/me, /updates, /diagnostics): a secret API key has no user, so it
          # gets a 404 rather than a 500 from a nil user.
          def require_current_user!
            return if current_user

            render_error(
              code: ERROR_CODES[:record_not_found],
              message: I18n.t('spree.me_no_current_user'),
              status: :not_found
            )
          end

          # For endpoints that reveal the running version and stack (/updates,
          # /diagnostics): a staff member signed in to the dashboard and nobody
          # else. A connected app acts as the admin who approved it, so it
          # would pass every check written for that admin, whatever it was
          # granted, and no scope stands for "fingerprint the deployment".
          def require_staff_session!
            return require_current_user! unless current_user
            return if current_oauth_token.blank?

            render_error(
              code: ERROR_CODES[:access_denied],
              message: 'This endpoint is for staff signed in to the dashboard, not for connected apps.',
              status: :forbidden
            )
          end
        end
      end
    end
  end
end
