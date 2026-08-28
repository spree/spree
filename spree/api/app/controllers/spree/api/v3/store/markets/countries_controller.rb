module Spree
  module Api
    module V3
      module Store
        module Markets
          # Uncached for the same reason as the top-level countries endpoint.
          class CountriesController < Store::BaseController
            allow_guest_storefront_access!

            before_action :load_market

            # GET /api/v3/store/markets/:market_id/countries
            def index
              render json: {
                data: @market.countries.map { |country| serialize_country(country) }
              }
            end

            # GET /api/v3/store/markets/:market_id/countries/:id
            def show
              iso = params[:id].to_s.upcase
              country = @market.countries.find { |candidate| candidate.iso == iso }
              raise ActiveRecord::RecordNotFound if country.nil?

              render json: serialize_country(country)
            end

            private

            # Scoped to the markets this channel sells into, so an unserved
            # market's countries 404 like the market itself
            # (docs/plans/6.0-channel-markets.md).
            def load_market
              scope = current_channel&.allowed_markets || current_store.markets
              @market = scope.find_by_prefix_id!(params[:market_id])
            end

            def serialize_country(country)
              Spree.api.country_serializer.new(country, params: serializer_params).to_h
            end
          end
        end
      end
    end
  end
end
