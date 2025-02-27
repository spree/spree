module Spree
  class PagesController < StoreController
    def show
      @current_page = @page = current_store.pages.custom.friendly.find(params[:id])
    end

    private

    def title
      @title ||= @page.meta_title.presence || @page.name
    end
  end
end
