module Spree
  module PageBlocks
    class Metafields < Spree::PageBlock
      preference :metafield_definition_ids, :array, default: []

      def icon_name
        'list'
      end
    end
  end
end
