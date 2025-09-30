module Spree
  module PageSections
    class ProductDetails < Spree::PageSection
      TOP_PADDING_DEFAULT = 20
      BOTTOM_PADDING_DEFAULT = 40

      def icon_name
        'list-details'
      end

      def self.role
        'system'
      end

      def default_blocks
        [
          Spree::PageBlocks::Products::Brand.new,
          Spree::PageBlocks::Products::Title.new,
          Spree::PageBlocks::Products::Price.new(text: Spree.t(:price), preferred_text_alignment: 'left'),
          Spree::PageBlocks::Products::VariantPicker.new,
          Spree::PageBlocks::Products::QuantitySelector.new,
          Spree::PageBlocks::Products::BuyButtons.new,
          Spree::PageBlocks::Products::Description.new
        ]
      end

      def blocks_available?
        true
      end

      def can_sort_blocks?
        true
      end

      def available_blocks_to_add
        [
          Spree::PageBlocks::Products::Brand,
          Spree::PageBlocks::Products::Title,
          Spree::PageBlocks::Products::Price,
          Spree::PageBlocks::Products::VariantPicker,
          Spree::PageBlocks::Products::QuantitySelector,
          Spree::PageBlocks::Products::BuyButtons,
          Spree::PageBlocks::Products::Description,
          Spree::PageBlocks::Metafields,
        ]
      end
    end
  end
end
