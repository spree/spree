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
            @settings ||= Spree::DataFeedSetting.find_by!(spree_store_id: current_store, uuid: params[:unique_url], enabled: true)
          end

          def data_feeds_google_rss_service
            Spree::Dependencies.data_feeds_google_rss_service.constantize.new.call(settings)
          end
        end
      end
    end
  end
end

