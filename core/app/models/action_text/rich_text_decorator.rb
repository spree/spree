module ActionText
  module RichTextDecorator
    def self.included(base)
      base.include ::Spree::PageBuilderUrl
      base.page_builder_route_with :policy_path, ->(rich_text) { rich_text.name.gsub(/customer_/, '') }
    end
  end

  ActionText::RichText.include(RichTextDecorator)
end
