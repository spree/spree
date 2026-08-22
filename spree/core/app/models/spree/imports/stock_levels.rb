module Spree
  module Imports
    class StockLevels < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::StockLevel
      end
    end
  end
end
