module Spree
  class PageSectionsController < StoreController
    helper_method :section_variables, :storefront_products_includes

    def show
      @section = Spree::PageSection.with_deleted.find(params[:id])
    end

    def section_variables
      @section_variables ||= begin
        variables = {}

        variables
      end
    end
  end
end
