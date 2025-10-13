module Spree
  module Imports
    class Products < Spree::Import
      def multi_line_csv?
        true
      end

      def row_processor_class
        Spree::Imports::RowProcessors::ProductVariant
      end
    end
  end
end
