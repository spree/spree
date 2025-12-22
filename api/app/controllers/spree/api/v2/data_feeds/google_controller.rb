module Spree
  module Api
    module V2
      module DataFeeds
        class GoogleController < ::Spree::Api::V2::BaseController
          def rss_feed
            send_data data_feeds_google_rss_service.value[:file], filename: 'products.rss', type: 'text/xml'
          end

          private

          def settings
            @settings ||= Spree::DataFeed::Google.find_by!(store: current_store, slug: params[:slug], active: true)
          end

          def data_feeds_google_rss_service
            Spree.data_feeds_google_rss_service.new.call(settings)
          end
        end
      end
    end
  end
end

