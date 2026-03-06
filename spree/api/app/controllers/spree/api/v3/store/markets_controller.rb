module Spree
  module Api
    module V3
      module Store
        class MarketsController < Store::BaseController
          include Spree::Api::V3::HttpCaching

          # GET /api/v3/store/markets
          def index
            markets = current_store.markets.includes(:countries).order(:position)

            return unless cache_collection(markets)

            render json: {
              data: markets.map { |market| serialize_market(market) }
            }
          end

          # GET /api/v3/store/markets/:id
          def show
            market = current_store.markets.includes(:countries).find_by_prefix_id!(params[:id])

            return unless cache_resource(market)

            render json: serialize_market(market)
          end

          # GET /api/v3/store/markets/resolve?country=DE
          def resolve
            country_iso = params[:country]&.upcase
            country = Spree::Country.find_by!(iso: country_iso)
            market = current_store.market_for_country(country)

            raise ActiveRecord::RecordNotFound unless market

            return unless cache_resource(market)

            render json: serialize_market(market)
          end

          private

          def serialize_market(market)
            Spree.api.market_serializer.new(market, params: serializer_params.merge(expand: expand_list + ['countries'])).to_h
          end
        end
      end
    end
  end
end
