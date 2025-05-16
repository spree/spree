module Spree
  module PageSections
    class FeaturedProduct < Spree::PageSection
      preference :product_id, :string, default: ''

      def icon_name
        'star'
      end

      def product
        return @product if defined?(@product)

        includes = [
          { variants: { images: [], prices: [], stock_items: [], stock_locations: [], option_values: :option_type } },
        ]

        @product ||= store.products.includes(includes).find_by(id: preferred_product_id)
      end

      def vendor_name
        return unless defined?(Spree::Vendor)

        @vendor_name ||= product&.vendor&.display_name || 'Brand'
      end

      def product_name
        product&.name
      end

      def default_blocks
        [
          Spree::PageBlocks::Products::Title.new,
          Spree::PageBlocks::Products::Price.new(text: 'Price', preferred_text_alignment: 'left'),
          Spree::PageBlocks::Products::VariantPicker.new,
          Spree::PageBlocks::Products::QuantitySelector.new,
          Spree::PageBlocks::Products::BuyButtons.new,
          Spree::PageBlocks::Products::Share.new(text: 'Share')
        ]
      end

      def blocks_available?
        true
      end

      def can_sort_blocks?
        true
      end
    end
  end
end
