module Spree
  class CmsPagesController < Spree::StoreController
    before_action :load_cms_page, only: [:show]

    def show
      @title = @cms_page.seo_title
    end

    private

    def load_cms_page
      @cms_page = Spree::CmsPage.friendly.find(params[:id])
    end
  end
end
