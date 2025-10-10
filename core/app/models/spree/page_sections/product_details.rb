module Spree
  module PageSections
    class ProductDetails < Spree::PageSection
      TOP_BORDER_WIDTH_DEFAULT = 0
      TOP_PADDING_DEFAULT = 0
      BOTTOM_PADDING_DEFAULT = 40

      def icon_name
        'list-details'
      end

      def self.role
        'system'
      end

      def default_blocks
        product_metafield_definition_ids = Spree::MetafieldDefinition.where(resource_type: 'Spree::Product').ids

        [
          Spree::PageBlocks::Products::Brand.new,
          Spree::PageBlocks::Products::Title.new,
          Spree::PageBlocks::Products::Price.new(text: Spree.t(:price), preferred_text_alignment: 'left'),
          Spree::PageBlocks::Products::VariantPicker.new,
          Spree::PageBlocks::Products::QuantitySelector.new,
          Spree::PageBlocks::Products::BuyButtons.new,
          Spree::PageBlocks::Products::Description.new,
          Spree::PageBlocks::Metafields.new(preferred_metafield_definition_ids: product_metafield_definition_ids),
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
