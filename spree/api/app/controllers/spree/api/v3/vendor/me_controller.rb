module Spree
  module Api
    module V3
      module Vendor
        # The signed-in seller: who they are, which vendors they act for, and
        # what they may do on the selected one.
        #
        # Structurally exempt from vendor scoping — this is what tells the
        # panel which X-Spree-Vendor-Id to send, so it has to answer before one
        # is chosen. Sending the header still narrows `permission_keys` to that
        # vendor.
        class MeController < Vendor::BaseController
          skip_scope_check!
          skip_before_action :set_current_vendor_context
          before_action :require_current_user!

          def show
            render json: me_response
          end

          private

          def me_response
            {
              user: Spree.api.admin_user_serializer.new(current_user, params: serializer_params).to_h,
              vendors: serialized_vendors,
              permission_keys: permission_keys
            }
          end

          def serialized_vendors
            current_user.vendors.map do |vendor|
              { id: vendor.prefixed_id, name: vendor.name, slug: vendor.slug, status: vendor.status }
            end
          end

          # Empty until a vendor is named: capability is per vendor, so there is
          # no meaningful answer spanning all of them.
          def permission_keys
            return [] if current_vendor.nil?

            ability = current_ability
            ability.respond_to?(:permission_keys) ? ability.permission_keys : []
          end

          def serializer_params
            { store: current_store || current_user.vendors.first&.store }
          end

          def require_current_user!
            return true if current_user

            render_error(
              code: ErrorHandler::ERROR_CODES[:record_not_found],
              message: Spree.t(:me_no_current_user),
              status: :not_found
            )
            false
          end
        end
      end
    end
  end
end
