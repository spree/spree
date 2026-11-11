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

      # @param invoice [Spree::Invoice]
      # @param store [Spree::Store] whose time zone the times are written in
      def initialize(invoice, store = invoice.store)
        @invoice = invoice
        @time_zone = Time.find_zone(store.preferred_timezone) || Time.zone
      end

      attr_reader :invoice

      def call
        [
          invoice.number,
          invoice.kind,
          invoice.issued_on&.iso8601,
          invoice.supplied_on&.iso8601,
          invoice.issuer_name,
          invoice.order&.number,
          invoice.seller_payout&.prefixed_id,
          invoice.original_invoice&.number,
          invoice.currency,
          amount(invoice.net_total),
          amount(invoice.tax_total),
          amount(invoice.total),
          invoice.source,
          invoice.external_reference,
          store_time(invoice.sent_at),
          store_time(invoice.created_at)
        ]
      end

      private

      def store_time(time)
        time&.in_time_zone(@time_zone)&.strftime('%Y-%m-%d %H:%M:%S')
      end

      def amount(value)
        Spree::Money::Rounding.format(value, invoice.currency) unless value.nil?
      end
    end
  end
end
