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

          protected

          # Feed URLs carry only a slug (unique per store, not globally), and
          # no credential accompanies the request — so feeds are served for
          # the default store. This matches the pre-6.0 behavior in practice:
          # the old finder resolved every host to the default store too. A
          # store-carrying feed URL shape is future work.
          def current_store
            @current_store ||= Spree::Store.default
          end
        end
      end
    end
  end
end
