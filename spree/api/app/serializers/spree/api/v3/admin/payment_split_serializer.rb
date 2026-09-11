module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::PaymentSplit — one child order's share of a payment
        # made against its order group.
        #
        # Read-only: the shares are written by the split at checkout and kept
        # current by the payment and refund subscribers.
        class PaymentSplitSerializer < V3::BaseSerializer
          AMOUNTS = %i[authorized_amount captured_amount refunded_amount claimed_amount
                       net_captured_amount refundable_amount].freeze

          typelize currency: :string,
                   payment_id: :string,
                   payment_number: 'string | null',
                   order_id: :string,
                   order_number: 'string | null',
                   authorized_amount: :string, display_authorized_amount: :string,
                   captured_amount: :string, display_captured_amount: :string,
                   refunded_amount: :string, display_refunded_amount: :string,
                   claimed_amount: :string, display_claimed_amount: :string,
                   net_captured_amount: :string, display_net_captured_amount: :string,
                   refundable_amount: :string, display_refundable_amount: :string

          attributes :currency, created_at: :iso8601, updated_at: :iso8601

          AMOUNTS.each do |amount|
            attribute(amount) { |split| split.public_send(amount).to_s }
            attribute(:"display_#{amount}") { |split| split.public_send(:"display_#{amount}").to_s }
          end

          attribute(:payment_id) { |split| split.payment&.prefixed_id }
          attribute(:payment_number) { |split| split.payment&.number }
          attribute(:order_id) { |split| split.order&.prefixed_id }
          attribute(:order_number) { |split| split.order&.number }
        end
      end
    end
  end
end
