module Spree
  module Api
    module V2
      module Storefront
        class AccountController < ::Spree::Api::V2::BaseController
          def show
            raise ActiveRecord::RecordNotFound if spree_current_user.nil?

            render_serialized_payload serialize_resource(resource)
          end

          private

          def resource
            spree_current_user
          end

          def serialize_resource(resource)
            dependencies[:resource_serializer].new(
              resource,
              include: resource_includes
            ).serializable_hash
          end

          def dependencies
            { resource_serializer: Spree::V2::Storefront::AccountSerializer }
          end
        end
      end
    end
  end
end
