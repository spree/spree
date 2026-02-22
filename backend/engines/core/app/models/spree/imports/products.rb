module Spree
  module Imports
    class Products < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::ProductVariant
      end

      def item_partial_name
        'variant'
      end
    end
  end
end
