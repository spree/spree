module Spree
  module Api
    module V3
      module Store
        module Markets
          class CountriesController < Store::BaseController
            before_action :load_market

            # GET /api/v3/store/markets/:market_id/countries
            def index
              countries = @market.countries.order(:name)

              render json: {
                data: countries.map { |country| serialize_country(country) }
              }
            end

            # GET /api/v3/store/markets/:market_id/countries/:id
            def show
              country = @market.countries.find_by!(iso: params[:id].upcase)

              render json: serialize_country(country)
            end

            private

            def load_market
              @market = current_store.markets.find_by_prefix_id!(params[:market_id])
            end

            def serialize_country(country)
              Spree.api.market_country_serializer.new(country, params: serializer_params).to_h
            end
          end
        end
      end
    end
  end
end
