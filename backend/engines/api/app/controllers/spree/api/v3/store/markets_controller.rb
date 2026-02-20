module Spree
  module Api
    module V3
      module Store
        class MarketsController < Store::BaseController
          # GET /api/v3/store/markets
          # Returns all markets with nested countries (for country/currency switcher)
          def index
            markets = current_store.markets.order(:position).includes(zone: { zone_members: :zoneable })

            render json: {
              data: markets.map { |market| serialize_market(market) }
            }
          end

          # GET /api/v3/store/markets/:id
          # Returns a single market with countries
          def show
            market = current_store.markets.find_by_prefix_id!(params[:id])

            render json: serialize_market(market)
          end

          # GET /api/v3/store/markets/resolve?country=DE
          # Resolves country ISO code to market
          def resolve
            country_iso = params[:country]&.upcase
            return render_error(code: 'invalid_params', message: 'country parameter is required', status: :bad_request) if country_iso.blank?

            country = Spree::Country.find_by(iso: country_iso)
            return render_error(code: 'record_not_found', message: 'country not found', status: :not_found) unless country

            market = current_store.market_for_country(country)
            return render_error(code: 'record_not_found', message: 'no market found for country', status: :not_found) unless market

            render json: serialize_market(market)
          end

          private

          def serialize_market(market)
            Spree.api.market_serializer.new(market, params: serializer_params).to_h
          end
        end
      end
    end
  end
end
