module Spree
  class CmsPagesController < Spree::StoreController
    before_action :load_cms_page, only: [:show]

    include Spree::FrontendHelper
    include Spree::CacheHelper

    def show
      if @cms_page_x.viewable?
        @cms_page = @cms_page_x
      elsif spree_current_user&.admin?
        @cms_page = @cms_page_x
        @edit_mode = true
      end
    end

    private

    def accurate_title
      if @cms_page_x
        @cms_page_x.seo_title
      else
        super
      end
    end

    def load_cms_page
      @cms_page_x = Spree::CmsPage.
                  by_store(current_store).
                  by_locale(I18n.locale).
                  friendly.find(params[:id])
    end
  end
end
