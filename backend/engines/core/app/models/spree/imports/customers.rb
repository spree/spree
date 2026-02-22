module Spree
  module Imports
    class Customers < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::Customer
      end

      def item_partial_name
        'customer'
      end
    end
  end
end
