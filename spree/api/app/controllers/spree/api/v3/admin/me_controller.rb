module Spree
  module Api
    module V3
      module Admin
        class MeController < Admin::BaseController
          skip_scope_check!

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
            unless current_user
              return render_error(
                code: ERROR_CODES[:record_not_found],
                message: Spree.t(:me_no_current_user),
                status: :not_found
              )
            end

            render json: {
              user: admin_user_serializer.new(current_user, params: serializer_params).to_h,
              permissions: serialize_permissions(current_ability)
            }
          end

          private

          # Serializes CanCanCan's rules into a flat, JSON-safe list of permission rules.
          #
          # - Rule order is preserved so the frontend matcher can apply
          #   CanCanCan's "last matching rule wins" semantics.
          # - Per-record conditions are NOT serialized (they often reference
          #   scopes or blocks that don't translate to JSON). The frontend
          #   receives `has_conditions: true` as a hint that the action might
          #   be denied at the per-record level — in practice the SPA shows
          #   the action optimistically and handles 403 from the API.
          def serialize_permissions(ability)
            ability.send(:rules).map do |rule|
              {
                allow: rule.base_behavior,
                actions: Array(rule.actions).map(&:to_s),
                subjects: Array(rule.subjects).map { |s| s.is_a?(Class) ? s.name : s.to_s },
                has_conditions: rule_has_conditions?(rule)
              }
            end
          end

          def rule_has_conditions?(rule)
            return true if rule.block.present?
            conditions = rule.conditions
            return false if conditions.nil?
            return !conditions.empty? if conditions.respond_to?(:empty?)

            true
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
