module Spree
  module Api
    module V2
      module Storefront
        class CountriesController < ::Spree::Api::V2::ResourceController
          private

          def serialize_collection(collection)
            collection_serializer.new(
              collection,
              collection_options(collection).merge(params: collection_serializer_params)
            ).serializable_hash
          end

          def collection_serializer_params
            {
              currency: current_currency,
              store: current_store,
              user: spree_current_user,
            }
          end

          def serializer_params
            {
              currency: current_currency,
              store: current_store,
              user: spree_current_user,
              include_states: true,
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
