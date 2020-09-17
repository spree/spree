module Spree
  module Api
    module V2
      module Storefront
        module Account
          class AddressesController < ::Spree::Api::V2::BaseController
            before_action :require_spree_current_user

            def index
              render_serialized_payload { serialize_collection(collection) }
            end

            def create
              result = create_service.call(user: spree_current_user, address_params: address_params)
              render_result(result)
            end

            def update
              result = update_service.call(address: resource, address_params: address_params)
              render_result(result)
            end

            private

            def collection
              collection_finder.new(scope: scope, params: params).execute
            end

            def resource
              @resource ||= scope.find(params[:id])
            end

            def scope
              spree_current_user.addresses
            end

            def collection_finder
              Spree::Api::Dependencies.storefront_address_finder.constantize
            end

            def collection_serializer
              Spree::Api::Dependencies.storefront_address_serializer.constantize
            end

            def resource_serializer
              Spree::Api::Dependencies.storefront_address_serializer.constantize
            end

            def serialize_collection(collection)
              collection_serializer.new(collection).serializable_hash
            end

            def create_service
              Spree::Api::Dependencies.storefront_account_create_address_service.constantize
            end

            def update_service
              Spree::Api::Dependencies.storefront_account_update_address_service.constantize
            end

            def address_params
              params.require(:address).permit(permitted_address_attributes)
            end

            def render_result(result)
              if result.success?
                render_serialized_payload { serialize_resource(result.value) }
              else
                render_error_payload(result.error)
              end
            end
          end
        end
      end
    end
  end
end
