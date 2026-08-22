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
          include Spree::Api::V3::PermissionSerialization

          skip_scope_check!
          skip_before_action :set_current_seller_context
          before_action :require_current_user!

          def show
            render json: me_response
          end

          private

          def me_response
            {
              user: Spree.api.seller_team_member_serializer.new(current_user, params: serializer_params).to_h,
              sellers: serialized_sellers,
              # Both shapes, exactly as the admin `/me`: the panel's `<Can>`
              # reads CanCanCan rules, the key gate reads keys. Sending only
              # keys left `<Can>` answering false for everything on the seller
              # panel — silently, since nothing gated on it yet.
              permissions: serialize_permissions(seller_ability),
              permission_keys: serialize_permission_keys(seller_ability)
            }
          end

          def serialized_sellers
            current_user.sellers.map do |seller|
              { id: seller.prefixed_id, name: seller.name, slug: seller.slug, status: seller.status }
            end
          end

          # Empty until a seller is named: capability is per seller, so there is
          # no meaningful answer spanning all of them. A bare ability (no
          # resource) serializes to nothing rather than raising, so the panel
          # can call `/me` before choosing a seller.
          def seller_ability
            return Spree::Ability.new(nil) if current_seller.nil?

            current_ability
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
