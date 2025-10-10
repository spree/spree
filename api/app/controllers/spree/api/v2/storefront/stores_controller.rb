module Spree
  module Api
    module V2
      module Storefront
        class StoresController < ::Spree::Api::V2::ResourceController
          def current
            render_serialized_payload { serialize_resource(current_store) }
          end

          private

          def model_class
            Spree::Store
          end

          def resource
            @resource ||= scope.find_by!(code: params[:code])
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_store_serializer.constantize
          end
        end
      end
    end
  end
end
