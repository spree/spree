module Spree
  module Api
    module V2
      module Platform
        class UsersController < ResourceController
          private

          def model_class
            Spree.user_class
          end

          def resource_serializer
            Spree.api.platform_user_serializer
          end

          def scope_includes
            [:ship_address, :bill_address]
          end

          # we need to define this here as developers can configure their own `user_class`
          def model_param_name
            'user'
          end

          def spree_permitted_attributes
            super + [:password, :password_confirmation]
          end

          # we need to override this method to avoid trying to create user role when creating a user
          def ensure_current_store(_resource)
            # do nothing
          end
        end
      end
    end
  end
end
