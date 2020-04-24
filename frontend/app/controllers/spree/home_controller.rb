module Spree
  class HomeController < Spree::StoreController
    respond_to :html

    def index
      if Spree::Frontend::Config[:http_cache_enabled]
        fresh_when etag: store_etag, last_modified: store_last_modified, public: true
      end
    end
  end
end
