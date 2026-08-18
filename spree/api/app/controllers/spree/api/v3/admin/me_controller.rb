module Spree
  module Api
    module V3
      module Admin
        class MeController < Admin::BaseController
          include Spree::Api::V3::PermissionSerialization

          skip_scope_check!

          before_action :require_current_user!

          # GET /api/v3/admin/me
          # Returns the current admin user along with a serialized representation
          # of their permissions (derived from CanCanCan rules). The SPA uses
          # the permissions list to decide which UI elements to show or hide.
          # The actual authorization check is still enforced server-side by
          # CanCanCan — the SPA list is purely for UX.
          #
          # This is the JWT-admin half of "describe the current credential"; the
          # secret-key half is GET /api/v3/admin/api_keys/current (see
          # ApiKeysController#current), which returns the key + its scopes.
          #
          # A request authenticated by a secret API key has no Spree user to
          # describe, so it gets a 404 pointing at the key endpoint rather than
          # a 500 from serializing a nil user — mirroring how #current 404s for
          # a JWT principal that has no single key.
          def show
            render json: me_response
          end

          # PATCH /api/v3/admin/me
          # Self-service update of the signed-in admin's own profile (display
          # name, admin UI language, and avatar) — it operates on `current_user`
          # directly, so it needs no per-record authorization. Distinct from
          # PATCH /admin_users/:id, which is store-scoped staff management of
          # *other* users. `avatar` accepts an ActiveStorage direct-upload
          # signed id to set the photo, or `null` to remove it.
          def update
            if current_user.update(permitted_params)
              render json: me_response
            else
              render_validation_error(current_user.errors)
            end
          end

          private

          # A request authenticated by a secret API key has no Spree user to
          # describe/update, so it gets a 404 pointing at the key endpoint
          # rather than a 500 from a nil user — mirroring ApiKeysController#current.
          def require_current_user!
            return if current_user

            render_error(
              code: ERROR_CODES[:record_not_found],
              message: Spree.t(:me_no_current_user),
              status: :not_found
            )
          end

          def permitted_params
            params.permit(:selected_locale, :first_name, :last_name, :avatar)
          end

          def me_response
            {
              user: admin_user_serializer.new(current_user, params: serializer_params).to_h,
              permissions: serialize_permissions(current_ability),
              permission_keys: serialize_permission_keys(current_ability)
            }
          end

          def admin_user_serializer
            Spree.api.admin_admin_user_serializer
          end

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              currency: current_currency,
              user: current_user,
              includes: []
            }
          end
        end
      end
    end
  end
end
