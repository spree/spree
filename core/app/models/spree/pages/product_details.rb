module Spree
  module Pages
    class ProductDetails < Spree::Page
      page_builder_route_with :product_path, ->(product_details) {
        store = product_details.store
        store.products.active.first || store.products.first
      }

      def icon_name
        'tag'
      end

      def default_sections
        [
          Spree::PageSections::ProductDetails.new,
          Spree::PageSections::RelatedProducts.new
        ]
      end

      def customizable?
        true
      end
    end
  end
end
