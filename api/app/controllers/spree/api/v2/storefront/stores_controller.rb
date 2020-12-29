module Spree
  module Api
    module V2
      module Storefront
        class StoresController < ::Spree::Api::V2::BaseController
          def show
            render_serialized_payload { serialize_resource(resource) }
          end

          private

          def scope
            Spree::Store
          end

          def resource
            scope.find_by!(code: params[:code])
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_store_serializer.constantize
          end
        end
      end
    end
  end
end
