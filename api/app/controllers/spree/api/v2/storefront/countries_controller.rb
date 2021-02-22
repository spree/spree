module Spree
  module Api
    module V2
      module Storefront
        class CountriesController < ::Spree::Api::V2::ResourceController
          private

          def serialize_collection(collection)
            collection_serializer.new(collection).serializable_hash
          end

          def serialize_resource(resource)
            resource_serializer.new(
              resource,
              include: resource_includes,
              fields: sparse_fields,
              params: resource_serializer_params
            ).serializable_hash
          end

          def resource_serializer_params
            {
              include_states: true,
              current_store: current_store
            }
          end

          def resource
            return scope.default if params[:iso] == 'default'

            scope.find_by(iso: params[:iso]&.upcase) ||
              scope.find_by(id: params[:iso]&.upcase) ||
              scope.find_by(iso3: params[:iso]&.upcase)
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_country_serializer.constantize
          end

          def collection_serializer
            Spree::Api::Dependencies.storefront_country_serializer.constantize
          end

          def collection_finder
            Spree::Api::Dependencies.storefront_country_finder.constantize
          end

          def model_class
            Spree::Country
          end
        end
      end
    end
  end
end
