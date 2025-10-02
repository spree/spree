module Spree
  module Pages
    class ProductDetails < Spree::Page
      def page_builder_url
        return unless page_builder_url_exists?(:product_path)

        product = store.products.active.first || store.products.first
        return if product.nil?

        Spree::Core::Engine.routes.url_helpers.product_path(product)
      end

      def icon_name
        'tag'
      end

      def default_sections
        [
          Spree::PageSections::Breadcrumbs.new,
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
