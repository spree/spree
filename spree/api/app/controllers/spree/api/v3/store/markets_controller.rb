module Spree
  module Api
    module V3
      module Store
        class MarketsController < Store::BaseController
          allow_guest_storefront_access!
          include Spree::Api::V3::HttpCaching

          # GET /api/v3/store/markets
          def index
            markets = served_markets.includes(:market_countries).ordered

            return unless cache_collection(markets)

            render json: {
              data: markets.map { |market| serialize_market(market) }
            }
          end

          # GET /api/v3/store/markets/:id
          def show
            market = served_markets.includes(:market_countries).find_by_prefix_id!(params[:id])

            return unless cache_resource(market)

            render json: serialize_market(market)
          end

          # GET /api/v3/store/markets/resolve?country=DE
          def resolve
            country_code = params[:country]&.upcase
            country = Spree::Country.find_by_iso!(country_code)
            market = current_store.market_for_country(country)

            # A market this channel does not sell into is as good as absent —
            # the 404 is deliberately indistinguishable from a country with no
            # market at all (docs/plans/6.0-channel-markets.md).
            raise ActiveRecord::RecordNotFound unless market
            raise ActiveRecord::RecordNotFound unless current_channel.nil? || current_channel.serves_market?(market)

            return unless cache_resource(market)

            render json: serialize_market(market)
          end

          private

          # The markets this storefront sells into. No allowlist on the
          # channel means every market of the store.
          def served_markets
            current_channel&.allowed_markets || current_store.markets
          end

          def serialize_market(market)
            Spree.api.market_serializer.new(market, params: serializer_params.merge(expand: expand_list + ['countries'])).to_h
          end
        end
      end
    end
  end
end
