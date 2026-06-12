module Spree
  module Api
    module V3
      module Admin
        class ApiKeysController < ResourceController
          # Dedicated scope — key management is credential-administration, not
          # store configuration. A `write_settings` key must not be able to
          # revoke or destroy higher-privileged keys.
          scoped_resource :api_keys

          # POST /api/v3/admin/api_keys
          # Prevents scope amplification: a key minted via a secret API key can
          # only carry scopes that key already holds. A JWT admin is governed by
          # CanCanCan (not scopes) and may grant any valid scope — so when a JWT
          # user authenticated the request, `current_ability` ignores the API key
          # (see AdminAuthentication#current_ability) and we skip the scope cap
          # too, even if an `X-Spree-Api-Key` header was also sent.
          def create
            if scope_limited_principal? && (excess = requested_scopes.reject { |s| current_api_key.has_scope?(s) }).any?
              return render_error(
                code: ERROR_CODES[:access_denied],
                message: "Cannot grant scopes beyond your own: #{excess.join(', ')}",
                status: :forbidden,
                details: { excess_scopes: excess }
              )
            end

            super
          end

          # PATCH /api/v3/admin/api_keys/:id/revoke
          # Marks the key revoked rather than deleting it — the row stays so
          # audit logs and `created_by`/`revoked_by` remain queryable. Hard
          # deletion is available via `destroy` for cleanup.
          def revoke
            @resource = find_resource
            authorize!(:update, @resource)

            @resource.revoke!(try_spree_current_user)
            render json: serialize_resource(@resource)
          end

          protected

          def model_class
            Spree::ApiKey
          end

          def serializer_class
            Spree.api.admin_api_key_serializer
          end

          def scope
            current_store.api_keys.accessible_by(current_ability, :show)
          end

          # Stamp the creating user; key generation (token, prefix, digest)
          # happens in `before_validation :generate_token` on the model.
          def build_resource
            scope.new(permitted_params).tap do |key|
              key.created_by = try_spree_current_user
            end
          end

          # `key_type` is set on create only — flipping a publishable key to a
          # secret one (or vice versa) would invalidate every consumer of the
          # plaintext token. We strip it on update so that's impossible to do
          # by accident through the API.
          def permitted_params
            attrs = params.permit(:name, :key_type, scopes: [])
            attrs.delete(:key_type) if action_name == 'update'
            attrs
          end

          private

          def requested_scopes
            Array(params[:scopes]).map(&:to_s).reject(&:blank?)
          end
        end
      end
    end
  end
end
