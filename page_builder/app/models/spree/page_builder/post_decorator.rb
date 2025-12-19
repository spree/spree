module Spree
  module PageBuilder
    module PostDecorator
      def self.prepended(base)
        base.include Spree::Linkable
      end

      def page_builder_url
        return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:post_path)

        Spree::Core::Engine.routes.url_helpers.post_path(self)
      end
    end
  end
end

Spree::Post.prepend(Spree::PageBuilder::PostDecorator)
