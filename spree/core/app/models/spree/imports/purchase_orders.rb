module Spree
  module Imports
    # Draft purchase orders from a supplier's line sheet. Rows sharing a
    # `reference` are one order; every order this import creates is a draft,
    # to be checked and placed from its own screen.
    class PurchaseOrders < Spree::Import
      def row_processor_class
        Spree::Imports::RowProcessors::PurchaseOrder
      end

      def group_column
        'reference'
      end

      def model_class
        Spree::PurchaseOrder
      end

      def self.model_class
        Spree::PurchaseOrder
      end

      def self.required_scope
        :purchasing
      end
    end
  end
end
