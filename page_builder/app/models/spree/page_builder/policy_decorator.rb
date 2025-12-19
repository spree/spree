module Spree
  module PageBuilder
    module PolicyDecorator
      def page_builder_url
        return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:policy_path)

        Spree::Core::Engine.routes.url_helpers.policy_path(self)
      end
    end
  end
end

Spree::Policy.prepend(Spree::PageBuilder::PolicyDecorator)
