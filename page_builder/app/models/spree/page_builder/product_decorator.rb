module Spree
  module PageBuilder
    module ProductDecorator
      def page_builder_url
        return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:product_path)

        Spree::Core::Engine.routes.url_helpers.product_path(self)
      end
    end
  end
end

Spree::Product.prepend(Spree::PageBuilder::ProductDecorator)
