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
            collection_serializer.new(collection).serializable_hash
          end

          def serialize_resource(resource)
            resource_serializer.new(
              resource,
              include: resource_includes,
              fields: sparse_fields,
              params: { include_states: true }
            ).serializable_hash
          end

          def collection
            collection_finder.new(scope, params).call
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

          def scope
            Spree::Country.accessible_by(current_ability, :show)
          end
        end
      end
    end
  end
end
