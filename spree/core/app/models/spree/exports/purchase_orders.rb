module Spree
  module Exports
    # Purchase orders as a supplier reads them: one row per line, the order's
    # header repeated on each. Filtered to one order, it is the file a merchant
    # sends to that supplier.
    class PurchaseOrders < Spree::Export
      def self.required_scope
        :purchasing
      end

      def self.model_class
        Spree::PurchaseOrder
      end

      def model_class
        Spree::PurchaseOrder
      end

      def scope_includes
        [:supplier, :destination_location, { items: { variant: :product } }]
      end

      def csv_headers
        Spree::CSV::PurchaseOrderItemPresenter::HEADERS
      end

      def generate_csv
        ::CSV.open(export_tmp_file_path, 'wb', encoding: 'UTF-8', col_sep: ',', row_sep: "\r\n") do |csv|
          csv << csv_headers
          records_to_export.includes(scope_includes).find_each do |purchase_order|
            purchase_order.items.each do |item|
              csv << Spree::CSV::FormulaSanitizer.row(Spree::CSV::PurchaseOrderItemPresenter.new(item).call)
            end
          end
        end
      end
    end
  end
end
