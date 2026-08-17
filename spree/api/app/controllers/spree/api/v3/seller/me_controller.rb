module Spree
  module Api
    module V3
      module Seller
        # The signed-in seller: who they are, which sellers they act for, and
        # what they may do on the selected one.
        #
        # Structurally exempt from seller scoping — this is what tells the
        # panel which X-Spree-Seller-Id to send, so it has to answer before one
        # is chosen. Sending the header still narrows `permission_keys` to that
        # seller.
        class MeController < Seller::BaseController
          skip_scope_check!
          skip_before_action :set_current_seller_context
          before_action :require_current_user!

          def show
            render json: me_response
          end

          private

          def me_response
            {
              user: Spree.api.admin_user_serializer.new(current_user, params: serializer_params).to_h,
              sellers: serialized_sellers,
              permission_keys: permission_keys
            }
          end

          def serialized_sellers
            current_user.sellers.map do |seller|
              { id: seller.prefixed_id, name: seller.name, slug: seller.slug, status: seller.status }
            end
          end

          # Empty until a seller is named: capability is per seller, so there is
          # no meaningful answer spanning all of them.
          def permission_keys
            return [] if current_seller.nil?

            ability = current_ability
            ability.respond_to?(:permission_keys) ? ability.permission_keys : []
          end

          def serializer_params
            { store: current_store || current_user.sellers.first&.store }
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
