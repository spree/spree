module Spree
  module Api
    module V2
      module Storefront
        class AccountController < ::Spree::Api::V2::ResourceController
          before_action :require_spree_current_user, except: :create

          def create
            result = create_service.call(user_params: user_create_params)
            render_result(result)
          end

          def update
            spree_authorize! :update, spree_current_user
            result = update_service.call(user: spree_current_user, user_params: user_update_params)
            render_result(result)
          end

          private

          def resource
            spree_current_user
          end

          def resource_serializer
            Spree.api.storefront_user_serializer
          end

          def model_class
            Spree.user_class
          end

          def create_service
            Spree.api.storefront_account_create_service
          end

          def update_service
            Spree.api.storefront_account_update_service
          end

          def user_create_params
            user_update_params.except(:bill_address_id, :ship_address_id)
          end

          def user_update_params
            params.require(:user).permit(permitted_user_attributes)
          end
        end
      end
    end
  end
end
