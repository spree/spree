module Spree
  module Api
    module V2
      module Storefront
        module Account
          class AddressesController < ::Spree::Api::V2::ResourceController
            include Spree::BaseHelper

            before_action :require_spree_current_user

            def create
              spree_authorize! :create, model_class

              result = create_service.call(user: spree_current_user, address_params: address_params)
              render_result(result)
            end

            def update
              spree_authorize! :update, resource

              result = update_service.call(address: resource, address_params: address_params)
              render_result(result)
            end

            def destroy
              spree_authorize! :destroy, resource

              if resource.destroy
                head 204
              else
                render_error_payload(resource.errors)
              end
            end

            private

            def collection
              collection_finder.new(scope: scope, params: finder_params).execute
            end

            def scope
              super.where(user: spree_current_user, country: available_countries).not_deleted
            end

            def model_class
              Spree::Address
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

            def create_service
              Spree::Api::Dependencies.storefront_address_create_service.constantize
            end

            def update_service
              Spree::Api::Dependencies.storefront_address_update_service.constantize
            end

            def address_params
              params.require(:address).permit(permitted_address_attributes)
            end
          end
        end
      end
    end
  end
end
