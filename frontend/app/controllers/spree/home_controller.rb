module Spree
  class HomeController < Spree::StoreController
    include Spree::CacheHelper

    respond_to :html

    def index
      if http_cache_enabled?
        fresh_when etag: store_etag, last_modified: store_last_modified, public: true
      end
    end
  end
end
