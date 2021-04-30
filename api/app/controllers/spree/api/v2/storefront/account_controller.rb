module Spree
  module Api
    module V2
      module Storefront
        class AccountController < ::Spree::Api::V2::ResourceController
          before_action :require_spree_current_user

          def update
            spree_authorize! :update, resource
            result = update_service.call(user: resource, user_params: user_params)
            render_result(result)
          end

          private

          def resource
            spree_current_user
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_user_serializer.constantize
          end

          def scope
            model_class.all
          end

          def model_class
            Spree.user_class
          end

          def update_service
            Spree::Api::Dependencies.storefront_account_update_service.constantize
          end

          def user_params
            params.require(:user).permit(permitted_user_attributes)
          end
        end
      end
    end
  end
end
