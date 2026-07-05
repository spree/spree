module Spree
  module Api
    module V3
      module Store
        class DataFeedsController < Store::BaseController
          skip_before_action :authenticate_api_key!
          skip_before_action :authenticate_user

          # GET /api/v3/store/feeds/:slug.xml
          def show
            data_feed = current_store.data_feeds.active.find_by!(slug: params[:slug])
            presenter = data_feed.class.presenter_class.new(data_feed)

            render xml: presenter.call
          end
        end
      end
    end
  end
end
