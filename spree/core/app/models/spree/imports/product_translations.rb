module Spree
  module Imports
    class ProductTranslations < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::ProductTranslation
      end

      def group_column
        'slug'
      end

      def model_class
        Spree::Product
      end

      def self.model_class
        Spree::Product
      end

      # Translation imports write products, so they share the products scope
      # (mirrors Spree::Exports::ProductTranslations.required_scope).
      def self.required_scope
        :products
      end
    end
  end
end
