module Spree
  module Api
    module V3
      module Admin
        class CountriesController < ResourceController
          scoped_resource :settings

          # Override base index to skip pagination — there are ~250 countries
          # and address-form dropdowns need them all at once. Pagy's global
          # max_limit (100) prevents using the paginated path for this.
          def index
            authorize!(:read, model_class)
            @collection = scope
            render json: { data: serialize_collection(@collection), meta: { count: @collection.size } }
          end

          protected

          def model_class
            Spree::Country
          end

          def serializer_class
            Spree.api.admin_country_serializer
          end

          def scope
            Spree::Country.all.order(:name).preload_associations_lazily
          end

          def find_resource
            scope.find_by!(iso: params[:id].upcase)
          end
        end
      end
    end
  end
end
