module Spree
  module Api
    module V2
      module Storefront
        class StoresController < ::Spree::Api::V2::BaseController
          def show
            render_serialized_payload { serialize_resource(resource) }
          end

          private

          def resource
            Spree::Store.find_by(params[:id])
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_store_serializer.constantize
          end
        end
      end
    end
  end
end
