module Spree
  class HomeController < Spree::StoreController
    include Spree::CacheHelper

    before_action :load_home_page, only: [:index]

    respond_to :html

    def index; end

    private

    def accurate_title
      if @home_page
        @home_page.seo_title
      else
        super
      end
    end

    def load_home_page
      @home_page = current_store.home_page(I18n.locale)
    end
  end
end
