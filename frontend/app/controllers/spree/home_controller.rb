module Spree
  class HomeController < Spree::StoreController
    include Spree::CacheHelper

    before_action :load_homepage, only: [:index]

    respond_to :html

    def index
      if @cms_home_page&.viewable?
        @homepage = @cms_home_page
      elsif try_spree_current_user&.admin?
        @homepage = @cms_home_page
        @edit_mode = true
      end

      if http_cache_enabled?
        fresh_when etag: store_etag, last_modified: store_last_modified, public: true
      end
    end

    private

    def accurate_title
      if @cms_home_page
        @cms_home_page.seo_title
      else
        super
      end
    end

    def load_homepage
      @cms_home_page = current_store.homepage(I18n.locale)
    end
  end
end
