module Spree
  module Exports
    # Every invoice, receipt and credit note in the store, one per row — what
    # an accountant asks for at the end of a period.
    class Invoices < Spree::Export
      def self.required_scope
        :orders
      end

      def self.model_class
        Spree::Invoice
      end

      def model_class
        Spree::Invoice
      end

      def scope_includes
        [:issuer, :order, :original_invoice, { seller_payout: :seller }]
      end

      def csv_headers
        Spree::CSV::InvoicePresenter::HEADERS
      end

      def generate_csv
        ::CSV.open(export_tmp_file_path, 'wb', encoding: 'UTF-8', col_sep: ',', row_sep: "\r\n") do |csv|
          csv << csv_headers
          records_to_export.includes(scope_includes).find_each do |invoice|
            csv << Spree::CSV::FormulaSanitizer.row(Spree::CSV::InvoicePresenter.new(invoice).call)
          end
        end
      end
    end
  end
end
