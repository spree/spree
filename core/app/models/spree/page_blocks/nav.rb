module Spree
  module PageBlocks
    class Nav < Spree::PageBlock
      preference :label, :string, default: Spree.t('page_blocks.nav.label_default')

      def icon_name
        'menu-2'
      end

      def display_name
        preferred_label
      end
    end
  end
end
