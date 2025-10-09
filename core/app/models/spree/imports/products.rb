module Spree
  module Imports
    class Products < Spree::Import
      def multi_line_csv?
        true
      end

      def handle_csv_line(record)

      end
    end
  end
end
