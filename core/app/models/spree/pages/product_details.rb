module Spree
  module Pages
    class ProductDetails < Spree::Page
      def url
        product = store.products.active.first || store.products.first

        Spree::Core::Engine.routes.url_helpers.product_path(product, locale: I18n.locale)
      end

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
