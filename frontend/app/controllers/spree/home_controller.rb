module Spree
  class HomeController < Spree::StoreController
    respond_to :html

    def index
      fresh_when etag: store_etag, last_modified: current_store.updated_at.utc, public: true
    end
  end
end
