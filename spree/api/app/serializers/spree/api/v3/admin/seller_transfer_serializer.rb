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
                   seller_name: 'string | null',
                   order_number: 'string | null',
                   kind: :string,
                   status: :string,
                   provider: :string,
                   amount: :string,
                   currency: :string,
                   reference: 'string | null',
                   display_amount: :string

          attributes :kind, :status, :currency, :provider, :reference, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          # A string, so the figure a seller is paid round-trips exactly.
          attribute(:amount) { |transfer| transfer.amount&.to_s }
          attribute(:display_amount) { |transfer| transfer.display_amount.to_s }

          %i[seller order payout reversed_from].each do |association|
            attribute(:"#{association}_id") { |transfer| transfer.public_send(association)&.prefixed_id }
          end

          # Both readable without expanding, since a ledger table is read row
          # by row and these are what identify a row to an operator.
          attribute(:seller_name) { |transfer| transfer.seller&.name }
          attribute(:order_number) { |transfer| transfer.order&.number }
        end
      end
    end
  end
end
