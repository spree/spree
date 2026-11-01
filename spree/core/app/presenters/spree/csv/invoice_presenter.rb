module Spree
  module CSV
    class InvoicePresenter
      HEADERS = [
        'Number',
        'Kind',
        'Issued On',
        'Supplied On',
        'Issuer',
        'Order Number',
        'Seller Payout',
        'Corrects',
        'Currency',
        'Net Total',
        'Tax Total',
        'Total',
        'Source',
        'External Reference',
        'Sent At',
        'Created At'
      ].freeze

      def initialize(invoice)
        @invoice = invoice
      end

      attr_reader :invoice

      def call
        [
          invoice.number,
          invoice.kind,
          invoice.issued_on&.iso8601,
          invoice.supplied_on&.iso8601,
          invoice.issuer.try(:legal_name).presence || invoice.issuer&.name,
          invoice.order&.number,
          invoice.seller_payout&.prefixed_id,
          invoice.original_invoice&.number,
          invoice.currency,
          invoice.net_total&.to_s('F'),
          invoice.tax_total&.to_s('F'),
          invoice.total.to_s('F'),
          invoice.source,
          invoice.external_reference,
          invoice.sent_at&.strftime('%Y-%m-%d %H:%M:%S'),
          invoice.created_at&.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
  end
end
