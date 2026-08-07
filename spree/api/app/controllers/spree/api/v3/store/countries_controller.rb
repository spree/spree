module Spree
  module Api
    module V3
      module Store
        # Deliberately uncached. The country list is reference data that only
        # changes with the countries gem, so the conditional-GET machinery had
        # nothing meaningful to key on: it fell back to the store's timestamp,
        # which invalidates on every unrelated store edit while never noticing
        # a change to the countries themselves.
        class CountriesController < Store::BaseController
          allow_guest_storefront_access!

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
