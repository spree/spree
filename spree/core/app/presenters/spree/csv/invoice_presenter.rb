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
          amount(invoice.net_total),
          amount(invoice.tax_total),
          amount(invoice.total),
          invoice.source,
          invoice.external_reference,
          invoice.sent_at&.strftime('%Y-%m-%d %H:%M:%S'),
          invoice.created_at&.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end

      private

      def amount(value)
        Spree::Money::Rounding.format(value, invoice.currency) unless value.nil?
      end
    end
  end
end
