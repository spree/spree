module Spree
  module Api
    module V3
      module Store
        module Markets
          class CountriesController < Store::BaseController
            # GET /api/v3/store/markets/:market_id/countries
            # Returns countries in the market (for checkout address dropdown)
            def index
              countries = market.countries.order(:name)

              render json: {
                data: countries.map { |country| serialize_country(country) }
              }
            end

            # GET /api/v3/store/markets/:market_id/countries/:id
            # Returns a single country with states (for address form validation)
            def show
              country = market.countries.find_by!(iso: params[:id].upcase)

              render json: serialize_country(country, include_states: true)
            end

            private

            def market
              @market ||= current_store.markets.find_by_prefix_id!(params[:market_id])
            end

            def serialize_country(country, include_states: false)
              data = Spree.api.country_serializer.new(country, params: { includes: [] }).to_h

              if include_states
                data[:states] = country.states.order(:name).map { |s| Spree.api.state_serializer.new(s).to_h }
              end

              data
            end
          end
        end
      end
    end
  end
end
