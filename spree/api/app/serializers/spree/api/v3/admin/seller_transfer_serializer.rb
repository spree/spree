module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::SellerTransfer — what one order earned one seller.
        #
        # Read-only: a transfer records money that moved, or is moving. What
        # corrects it is a reversal, which is another row rather than an edit.
        class SellerTransferSerializer < V3::BaseSerializer
          typelize seller_id: :string,
                   order_id: 'string | null',
                   payout_id: 'string | null',
                   reversed_from_id: 'string | null',
                   refund_id: 'string | null',
                   seller_name: 'string | null',
                   order_number: 'string | null',
                   kind: [:string, enum: Spree::SellerTransfer::KINDS],
                   status: [:string, enum: Spree::SellerTransfer.statuses, enum_type_name: 'SellerTransferStatus'],
                   provider: [:string, comment: 'Payout provider. Built-in: system. Provider gems register more (e.g. stripe).'],
                   amount: :string,
                   currency: :string,
                   settled_amount: 'string | null',
                   settled_currency: 'string | null',
                   converted: :boolean,
                   reference: 'string | null'

          attributes :kind, :status, :currency, :reference, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute(:amount) { |transfer| Spree::Money::Rounding.format(transfer.amount, transfer.currency) }

          # What the seller's account received, when the provider converted on
          # the way in. Null when it settled in the currency of the sale.
          attribute(:settled_amount) do |transfer|
            Spree::Money::Rounding.format(transfer.settled_amount, transfer.settled_currency || transfer.currency)
          end
          attribute(:settled_currency) { |transfer| transfer.settled_currency }
          attribute(:converted) { |transfer| transfer.converted? }

          %i[seller order payout reversed_from refund].each do |association|
            attribute(:"#{association}_id") { |transfer| transfer.public_send(association)&.prefixed_id }
          end

          # Both readable without expanding, since a ledger table is read row
          # by row and these are what identify a row to an operator.
          attribute(:seller_name) { |transfer| transfer.seller&.name }
          attribute(:order_number) { |transfer| transfer.order&.number }

          api_type_attributes :provider
        end
      end
    end
  end
end
