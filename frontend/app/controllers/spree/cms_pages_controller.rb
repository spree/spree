module Spree
  class CmsPagesController < Spree::StoreController
    before_action :load_cms_page, only: [:show]

    include Spree::FrontendHelper
    include Spree::CacheHelper

    def show
      if @page&.viewable?
        @cms_page = @page
      elsif try_spree_current_user&.admin?
        @cms_page = @page
        @edit_mode = true
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    private

    def accurate_title
      if @page
        @page.seo_title
      else
        super
      end
    end

    def load_cms_page
      @page = Spree::CmsPage.
              by_store(current_store).
              friendly.find(params[:id])
    end
  end
end
