module Spree
  module Api
    module V3
      module Seller
        # One settlement to this seller, as the seller reads it.
        class PayoutSerializer < V3::BaseSerializer
          typelize status: :string,
                   currency: :string,
                   provider: :string,
                   amount: :string,
                   display_amount: :string,
                   reference: 'string | null',
                   period_start: 'string | null',
                   period_end: 'string | null',
                   transfers_count: :number

          attributes :status, :currency, :provider, :reference,
                     period_start: :iso8601, period_end: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute(:amount) { |payout| payout.amount&.to_s }
          attribute(:display_amount) { |payout| payout.display_amount.to_s }

          # How many earnings this settlement covers. Read from a count the
          # controller made for the whole page when there is one; a single
          # payout read falls back to asking for its own.
          attribute(:transfers_count) do |payout, params|
            counts = params && params[:transfer_counts]

            counts ? counts.fetch(payout.id, 0) : payout.transfers.count
          end
        end
      end
    end
  end
end
