module Spree
  module Api
    module V2
      module Storefront
        class AccountController < ::Spree::Api::V2::BaseController
          before_action :require_spree_current_user

          def show
            render_serialized_payload { serialize_resource(resource) }
          end

          private

          def resource
            spree_current_user
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_user_serializer.constantize
          end
        end
      end
    end
  end
end
