module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::SellerPayout — one settlement to one seller.
        #
        # Created by the sweep rather than by a caller, so the API offers no
        # create or update. The one thing an operator does to a payout is say
        # it landed, which is its own member action.
        class SellerPayoutSerializer < V3::BaseSerializer
          typelize seller_id: :string,
                   seller_name: 'string | null',
                   status: :string,
                   provider: :string,
                   amount: :string,
                   currency: :string,
                   reference: 'string | null',
                   period_start: 'string | null',
                   period_end: 'string | null',
                   transfers_count: :number,
                   display_amount: :string

          attributes :status, :currency, :provider, :reference, :metadata,
                     period_start: :iso8601, period_end: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute(:amount) { |payout| payout.amount&.to_s }
          attribute(:display_amount) { |payout| payout.display_amount.to_s }
          attribute(:seller_id) { |payout| payout.seller&.prefixed_id }
          attribute(:seller_name) { |payout| payout.seller&.name }

          # How many earnings this settlement covers, so a list answers "what
          # is in this deposit" without loading every transfer.
          #
          # Read from a count the controller made for the whole page when there
          # is one; a single payout read falls back to asking for its own.
          attribute(:transfers_count) do |payout, params|
            counts = params && params[:transfer_counts]

            counts ? counts.fetch(payout.id, 0) : payout.transfers.count
          end
        end
      end
    end
  end
end
