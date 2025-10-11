module Spree
  module Imports
    class Products < Spree::Import
      def multi_line_csv?
        true
      end

      def row_handler_class
        Spree::Imports::RowHandlers::ProductVariant
      end
    end
  end
end
