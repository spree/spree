module Spree
  module Imports
    class ProductTranslations < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::ProductTranslation
      end

      def model_class
        Spree::Product
      end

      def self.model_class
        Spree::Product
      end
    end
  end
end
