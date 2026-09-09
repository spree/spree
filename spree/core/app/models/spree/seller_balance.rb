module Spree
  # One seller's position in one currency, read off the fund ledger.
  #
  # Never persisted: every figure is a sum over {Spree::SellerTransfer} and
  # {Spree::SellerPayout} rows, so the ledger stays the only record and this
  # only presents it. One per currency — a marketplace paying a seller in two
  # currencies has two ledgers, and adding them would answer a question nobody
  # asked.
  class SellerBalance
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :seller
    attribute :currency, :string
    # What the seller has earned: completed transfers, reversals included.
    attribute :earned, :decimal, default: 0
    # What has reached them: completed settlements.
    attribute :paid, :decimal, default: 0
    # Earnings still with the provider — a transfer not yet confirmed, or one
    # whose outcome is unknown. Shown so a shipped order does not read as
    # unpaid while the money is in flight.
    attribute :pending, :decimal, default: 0

    extend Spree::DisplayMoney
    money_methods :earned, :paid, :pending, :balance

    # @param seller [Spree::Seller]
    # @param currency [String]
    # @return [Spree::SellerBalance]
    def self.for(seller, currency)
      transfers = seller.seller_transfers.where(currency: currency)

      new(
        seller: seller,
        currency: currency,
        earned: transfers.completed.sum(:amount),
        pending: transfers.with_status('pending', 'processing', 'unresolved').sum(:amount),
        paid: seller.seller_payouts.completed.where(currency: currency).sum(:amount)
      )
    end

    # What the marketplace still owes — the same figure {Spree::Seller#balance}
    # answers, which is what the payout sweep settles.
    #
    # @return [BigDecimal]
    def balance
      earned - paid
    end
  end
end
