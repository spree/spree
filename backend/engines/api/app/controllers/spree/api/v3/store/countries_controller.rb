module Spree
  module Api
    module V3
      module Store
        class CountriesController < Store::BaseController
          # GET /api/v3/store/countries
          def index
            countries = current_store.countries_from_markets

            render json: {
              data: countries.map { |country| serialize_country(country) }
            }
          end

          # GET /api/v3/store/countries/:id
          def show
            country = current_store.countries_from_markets.find_by!(iso: params[:id].upcase)

            render json: serialize_country(country)
          end

          private

          def serialize_country(country)
            Spree.api.country_serializer.new(country, params: serializer_params).to_h
          end
        end
      end
    end
  end
end
