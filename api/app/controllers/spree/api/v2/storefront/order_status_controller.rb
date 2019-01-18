module Spree
  module Api
    module V2
      module Storefront
        class OrderStatusController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::CollectionOptionsHelpers

          def show
            render_serialized_payload { serialize_resource(resource) }
          end

          private

          def resource
            resource = dependencies[:resource_finder].new(number: params[:number]).execute.take
            raise ActiveRecord::RecordNotFound if resource.nil?

            resource
          end

          def serialize_resource(resource)
            dependencies[:resource_serializer].new(
              resource,
              include: resource_includes,
              sparse_fields: sparse_fields
            ).serializable_hash
          end

          def dependencies
            {
              resource_finder: Spree::Orders::FindComplete,
              resource_serializer: Spree::V2::Storefront::CartSerializer,
            }
          end
        end
      end
    end
  end
end
