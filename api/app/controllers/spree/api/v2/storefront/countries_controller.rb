module Spree
  module Api
    module V2
      module Storefront
        class CountriesController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::CollectionOptionsHelpers

          def show
            render_serialized_payload serialize_resource(resource)
          end

          private

          def serialize_resource(resource)
            dependencies[:resource_serializer].new(
              resource,
              include: resource_includes
            ).serializable_hash
          end

          def resource
            return Spree::Country.default if params[:id] == 'default'

            scope.find_by(iso: params[:id].upcase) ||
              scope.find_by(iso3: params[:id].upcase)
          end

          def dependencies
            {
              resource_serializer: Spree::V2::Storefront::CountrySerializer
            }
          end

          def scope
            Spree::Country.accessible_by(current_ability, :read).includes(scope_includes)
          end

          def scope_includes
            %w[states]
          end
        end
      end
    end
  end
end
