module Spree
  module PageBlocks
    class Link < Spree::PageBlock
      include Spree::HasOneLink

      def icon_name
        'menu-2'
      end

      def display_name
        link&.label || Spree.t('page_blocks.link.display_name')
      end

      def link_destroyed(_link)
        return unless page_links_count.zero?

        destroy
      end
    end
  end
end
