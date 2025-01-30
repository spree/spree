module Spree
  module Pages
    class Custom < Spree::Page
      page_builder_route_with :page_path, ->(page) { page }

      def customizable?
        true
      end

      def default_sections
        [
          Spree::PageSections::PageTitle.new,
          Spree::PageSections::RichText.new
        ]
      end

      def promote
        return unless preview?

        ApplicationRecord.transaction do
          old_page = parent
          old_page.page_links.update_all(linkable_id: id)
          update(parent: nil) # clear reference to the old page
          Spree::Page.find(old_page.id).destroy # destroy the old page with their other previews, etc.
          update_columns(slug: old_page.slug)
        end
      end
    end
  end
end
