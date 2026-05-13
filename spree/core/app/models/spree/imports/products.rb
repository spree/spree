module Spree
  module Imports
    class Products < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::ProductVariant
      end

      # Group by slug: product row + its variant rows must be processed together
      def group_column
        'slug'
      end
    end
  end
end
