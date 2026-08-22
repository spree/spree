module Spree
  module Imports
    class Prices < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::Price
      end
    end
  end
end
