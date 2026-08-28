module Spree
  module Exports
    class Orders < Spree::Export
      SELLER_OMITTED_HEADERS = ['Email'].freeze

      def scope_includes
        [
          :store,
          :payments,
          :shipments,
          :bill_address,
          :ship_address,
          { line_items: { variant: { product: [:categories] } } },
          { custom_fields: :custom_field_definition }
        ]
      end

      def multi_line_csv?
        true
      end

      def csv_headers
        Spree::CSV::OrderLineItemPresenter.headers(omit_headers: omitted_headers) + custom_fields_headers
      end

      def to_csv_options
        { omit_headers: omitted_headers }
      end

      # Columns a seller's own export leaves out.
      #
      # The buyer's email is withheld from every seller-facing surface — it is
      # the one contact detail that lets a marketplace's customer be taken off
      # the marketplace, and `Spree::Api::V3::Seller::OrderSerializer` already
      # withholds it. A bulk CSV that carried it would hand over in a
      # spreadsheet exactly what the order page refuses to show, and would
      # undo the message relay this is the counterpart to
      # (docs/plans/6.1-marketplace-message-relay.md).
      #
      # The addresses stay, phones included, and deliberately so: a seller is
      # merchant of record for their own child order, so they ship to one and
      # invoice against the other, and until the relay ships the phone on the
      # shipping address is a seller's only way to reach a buyer about a
      # delivery (docs/plans/6.1-marketplace-message-relay.md). Email is
      # withheld where the phone is not because email is the channel that
      # takes a customer off the marketplace, while a delivery phone number is
      # what makes the parcel arrive.
      #
      # @return [Array<String>]
      def omitted_headers
        seller.present? ? SELLER_OMITTED_HEADERS : []
      end
    end
  end
end
