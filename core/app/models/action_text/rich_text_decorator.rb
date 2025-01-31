module ActionText
  module RichTextDecorator
    def page_builder_url
      return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:policy_path)

      Spree::Core::Engine.routes.url_helpers.policy_path(name.gsub(/customer_/, ''))
    end
  end

  ActionText::RichText.include(RichTextDecorator)
end
