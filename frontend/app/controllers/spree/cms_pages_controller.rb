module Spree
  class CmsPagesController < Spree::StoreController
    before_action :load_cms_page, only: [:show]

    include Spree::FrontendHelper
    include Spree::CacheHelper

    def show; end

    private

    def accurate_title
      if @cms_page
        @cms_page.seo_title
      else
        super
      end
    end

    def load_cms_page
      @cms_page = Spree::CmsPage.visible.by_store(current_store).friendly.find(params[:id])
    end
  end
end
