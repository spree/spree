module Spree
  module Imports
    class Products < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::ProductVariant
      end
    end
  end
end
