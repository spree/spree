module Spree
  module Api
    module V3
      module Admin
        # Mirrors Admin::BaseController's concerns. Both classes anchor parallel
        # inheritance branches (V3::BaseController vs V3::ResourceController);
        # any concern added here MUST also be added to Admin::BaseController.
        class ResourceController < Spree::Api::V3::ResourceController
          include Spree::Api::V3::Admin::StoreContext
          include Spree::Api::V3::AdminAuthentication
          include Spree::Api::V3::ScopedAuthorization
          # External-identity addressing for every admin resource whose model
          # opts in via Spree::HasExternalReferences — the concern's guards
          # no-op for everything else. Sitting here rather than per controller
          # means a newly synced resource cannot ship the half-supported state
          # (readable references, unaddressable member paths) by forgetting an
          # include.
          include Spree::Api::V3::Admin::Concerns::ExternalReferences
          include Spree::Api::V3::Admin::ValidationDetails

          protected

          def authenticate_request!
            authenticate_admin!
          end

          # CanCanCan lives on the admin branch only. The shared base leaves
          # these as no-ops because the Store API authorizes by ownership
          # scoping; back-office callers are authorized per record and per
          # collection by their role's catalog keys.
          def scope
            base_scope = super
            return base_scope if @parent.present?

            base_scope.accessible_by(current_ability, ability_action_for_request)
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            authorize!(action, resource)
          end

          def authorize_parent!(parent)
            authorize!(parent_ability_action, parent)
          end

          # Render error from ServiceModule::Result, extracting ActiveModel::Errors
          # from the ResultError wrapper to get proper validation_error responses.
          def decode_ids(ids, klass)
            Array(ids).map do |id|
              Spree::PrefixedId.prefixed_id?(id) ? klass.find_by_param!(id).id : id
            end
          end

          def decode_prefixed_ids(ids)
            Array(ids).map do |id|
              Spree::PrefixedId.prefixed_id?(id) ? Spree::PrefixedId.decode_prefixed_id(id) : id
            end
          end

          # Returns +url+ only when it matches one of the store's configured
          # allowed origins — the gate for caller-provided URLs that later
          # surface outside the request (e.g. the results_url the import/export
          # done emails link back to). Anything else is silently dropped,
          # mirroring the password-reset redirect_url behavior: no configured
          # origins means no caller URLs are honored.
          # @return [String, nil]
          def validated_allowed_origin_url(url)
            return if url.blank?
            return unless current_store.allowed_origin?(url)

            url
          end

          # Parses a strictly-integer param, returning nil for missing/blank/
          # non-integer values (so callers can reject rather than coerce to 0).
          # @return [Integer, nil]
          def integer_param(name)
            value = params[name]
            Integer(value, exception: false) if value.is_a?(Integer) || value.to_s.match?(/\A-?\d+\z/)
          end

          # Renders a 422 for a missing/invalid +new_position+.
          def render_invalid_position
            render_error(
              code: ERROR_CODES[:validation_error],
              message: Spree.t('api.errors.invalid_position', default: 'new_position must be an integer'),
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
