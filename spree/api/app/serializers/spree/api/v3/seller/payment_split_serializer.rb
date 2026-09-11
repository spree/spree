module Spree
  module Api
    module V3
      module Seller
        # This order's share of the payment the buyer made for the whole
        # basket (Spree::PaymentSplit), as the seller reads it.
        #
        # Amounts only. Which payment it is a share of, how the buyer paid and
        # what the gateway said are the marketplace's — the seller's question
        # is how much of their order was captured, refunded, and can still be
        # refunded.
        class PaymentSplitSerializer < V3::BaseSerializer
          AMOUNTS = %i[authorized_amount captured_amount refunded_amount claimed_amount
                       net_captured_amount refundable_amount].freeze

          typelize currency: :string,
                   authorized_amount: :string, display_authorized_amount: :string,
                   captured_amount: :string, display_captured_amount: :string,
                   refunded_amount: :string, display_refunded_amount: :string,
                   claimed_amount: :string, display_claimed_amount: :string,
                   net_captured_amount: :string, display_net_captured_amount: :string,
                   refundable_amount: :string, display_refundable_amount: :string

          attributes :currency, created_at: :iso8601

          AMOUNTS.each do |amount|
            attribute(amount) { |split| split.public_send(amount).to_s }
            attribute(:"display_#{amount}") { |split| split.public_send(:"display_#{amount}").to_s }
          end
        end
      end
    end
  end
end
