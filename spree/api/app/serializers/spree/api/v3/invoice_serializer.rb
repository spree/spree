module Spree
  module Api
    module V3
      # A buyer's view of an invoice, receipt or credit note: what it is,
      # who issued it, its totals, and where to download it. No timestamps,
      # upload details or internal references.
      class InvoiceSerializer < BaseSerializer
        typelize kind: [:string, enum: Spree::Invoice::KINDS, enum_type_name: 'InvoiceKind'],
                 number: :string,
                 issued_on: :string,
                 supplied_on: [:string, nullable: true],
                 currency: [:string, enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode'],
                 issuer_type: [:string, enum: Spree::Invoice::ISSUER_TYPES.map { |type| Spree::Base.polymorphic_api_type(type) }, enum_type_name: 'InvoiceIssuerType'],
                 issuer_name: [:string, nullable: true],
                 original_invoice_id: [:string, nullable: true],
                 download_url: [:string, nullable: true]

        attributes :kind, :number, :currency

        attribute(:issued_on) { |invoice| invoice.issued_on&.iso8601 }
        attribute(:supplied_on) { |invoice| invoice.supplied_on&.iso8601 }

        money_attributes :total, :net_total, :tax_total
        typelize total: [:string, nullable: false]

        prefixed_id_attributes :original_invoice

        attribute :issuer_type do |invoice|
          Spree::Base.polymorphic_api_type(invoice.issuer_type)
        end

        attribute :issuer_name, &:issuer_name

        private_file_attributes :file

        # Our own endpoint, streamed to whoever owns the order.
        attribute :download_url do |invoice|
          next nil unless invoice.order && invoice.file.attached?

          Spree::Core::Engine.routes.url_helpers.download_api_v3_store_order_invoice_path(
            order_id: invoice.order.prefixed_id, id: invoice.prefixed_id
          )
        end
      end
    end
  end
end
