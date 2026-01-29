module Spree
  module Themes
    class DuplicateComponentsJob < Spree::BaseJob
      queue_as Spree.queues.themes

      # We need to duplicate:
      # 1. Theme files + sections with pageable_type Spree::Theme.
      # 2. Duplicate pages + sections.
      # 3. Adjust linkable on page links for Spree::PageSection and Spree::PageBlock parents and Spree::Page linkable.

      def perform(theme_id, duplicated_theme_id)
        theme = Spree::Theme.find(theme_id)
        duplicated_theme = Spree::Theme.find(duplicated_theme_id)

        ApplicationRecord.transaction do
          duplicated_pages = duplicate_pages(theme, duplicated_theme)

          # Duplicated links on pages and blocks have references to pages from the previous theme
          # We need to look for a duplicated page and update the link with it
          duplicate_layout_sections(theme, duplicated_theme)
          adjust_page_links(theme, duplicated_theme, duplicated_pages)

          duplicated_theme.update!(ready: true)
        end
      end

      private

      def duplicate_layout_sections(theme, duplicated_theme)
        theme.layout_sections.each { |section| section.deep_clone(duplicated_theme) }
      end

      def duplicate_pages(theme, duplicated_theme)
        theme.pages.map { |page| page.duplicate(duplicated_theme) }
      end

      def adjust_page_links(theme, duplicated_theme, duplicated_pages)
        page_sections = Spree::PageSection.where(pageable: duplicated_pages)
        layout_sections = duplicated_theme.layout_sections
        all_section_ids = page_sections.ids + layout_sections.ids

        all_page_blocks = Spree::PageBlock.where(section_id: all_section_ids)

        all_parent_ids = all_section_ids + all_page_blocks.ids
        all_page_links = Spree::PageLink.
                          preload(:linkable, parent: :pageable).
                          where(linkable_type: 'Spree::Page').
                          where(parent_id: all_parent_ids, linkable_id: theme.pages)

        all_page_links.each do |page_link|
          linkable_type = page_link.linkable.type
          duplicated_page = duplicated_theme.pages.find_by(type: linkable_type)

          page_link.update!(linkable: duplicated_page)
        end
      end
    end
  end
end
