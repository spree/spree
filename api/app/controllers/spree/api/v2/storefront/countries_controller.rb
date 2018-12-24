module Spree
  module Api
    module V2
      module Storefront
        class CountriesController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::CollectionOptionsHelpers

          def index
            render_serialized_payload { serialize_collection(collection) }
          end

          def show
            render_serialized_payload { serialize_resource(resource) }
          end

          private

          def serialize_collection(collection)
            dependencies[:collection_serializer].new(collection).serializable_hash
          end

          def serialize_resource(resource)
            dependencies[:resource_serializer].new(
              resource,
              include: resource_includes,
              params: { include_states: true }
            ).serializable_hash
          end

          def collection
            scope
          end

          def resource
            return scope.default if params[:iso] == 'default'

            scope.find_by(iso: params[:iso]&.upcase) ||
              scope.find_by(iso3: params[:iso]&.upcase)
          end

          def dependencies
            {
              collection_serializer: Spree::V2::Storefront::CountrySerializer,
              resource_serializer: Spree::V2::Storefront::CountrySerializer
            }
          end

          def scope
            Spree::Country.accessible_by(current_ability, :read)
          end
        end
      end
    end
  end
end
