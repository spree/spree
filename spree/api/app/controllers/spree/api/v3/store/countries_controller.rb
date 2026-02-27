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
            Spree.api.country_serializer.new(country, params: serializer_params.merge(market_by_country_id: market_by_country_id)).to_h
          end

          def market_by_country_id
            @market_by_country_id ||= begin
              hash = {}
              current_store.markets.includes(:market_countries).order(:position).each do |market|
                market.market_countries.each { |mc| hash[mc.country_id] ||= market }
              end
              hash
            end
          end
        end
      end
    end
  end
end
