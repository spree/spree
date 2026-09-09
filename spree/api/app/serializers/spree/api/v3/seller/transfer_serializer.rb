module Spree
  module Api
    module V3
      module Seller
        # What one of this seller's orders earned them, as the seller reads it.
        #
        # Declared from the base rather than the admin serializer so nothing
        # leaks by inheritance: the provider's metadata and the refund behind a
        # reversal are the marketplace's, and there is one seller in play so
        # naming them on every row would only repeat the header.
        class TransferSerializer < V3::BaseSerializer
          typelize kind: :string,
                   status: :string,
                   currency: :string,
                   provider: :string,
                   amount: :string,
                   display_amount: :string,
                   reference: 'string | null',
                   order_id: 'string | null',
                   order_number: 'string | null',
                   payout_id: 'string | null',
                   reversed_from_id: 'string | null'

          attributes :kind, :status, :currency, :provider, :reference,
                     created_at: :iso8601, updated_at: :iso8601

          # A string, so the figure a seller is paid round-trips exactly.
          attribute(:amount) { |transfer| transfer.amount&.to_s }
          attribute(:display_amount) { |transfer| transfer.display_amount.to_s }

          %i[order payout reversed_from].each do |association|
            attribute(:"#{association}_id") { |transfer| transfer.public_send(association)&.prefixed_id }
          end

          attribute(:order_number) { |transfer| transfer.order&.number }
        end
      end
    end
  end
end
