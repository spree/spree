module Spree
  # One seller's position in one currency, read off the fund ledger.
  #
  # Never persisted: every figure is a sum over {Spree::SellerTransfer} and
  # {Spree::SellerPayout} rows, so the ledger stays the only record and this
  # only presents it. One per currency — a marketplace paying a seller in two
  # currencies has two ledgers, and adding them would answer a question nobody
  # asked.
  #
  # A position has two sides when the seller's account settles in a currency
  # other than the one they sold in: what the sale was worth, and what their
  # account received once the provider converted it. Both are recorded figures.
  # They are never added together, and Spree converts nothing itself.
  class SellerBalance
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :seller
    # What the sales were priced in.
    attribute :currency, :string
    # What the seller's account holds, and is paid in. The same as `currency`
    # unless the provider converted on the way in.
    attribute :settlement_currency, :string
    # What the seller has earned: completed transfers, reversals included.
    attribute :earned, :decimal, default: 0
    # Earnings still with the provider — a transfer not yet confirmed, or one
    # whose outcome is unknown. Shown so a shipped order does not read as
    # unpaid while the money is in flight.
    attribute :pending, :decimal, default: 0
    # The same completed earnings, as their account received them.
    attribute :payable, :decimal, default: 0
    # How much of that has reached them, through settlements that completed.
    attribute :paid, :decimal, default: 0

    extend Spree::DisplayMoney
    money_methods :earned, :pending

    # @param seller [Spree::Seller]
    # @param currency [String] what the sales were priced in
    # @param settlement_currency [String] what the account settles in
    # @return [Spree::SellerBalance]
    def self.for(seller, currency, settlement_currency = currency)
      transfers = seller.seller_transfers.where(currency: currency).settling_in(settlement_currency)

      new(
        seller: seller,
        currency: currency,
        settlement_currency: settlement_currency,
        earned: transfers.completed.sum(:amount),
        pending: transfers.with_status('pending', 'processing', 'unresolved').sum(:amount),
        payable: transfers.completed.settlement_total,
        # Read through the transfers a settlement claimed rather than off the
        # settlement's own total: two sale currencies can settle into one, and
        # the payout's figure would then count against both of them.
        paid: transfers.completed.joins(:payout).
              merge(Spree::SellerPayout.completed).settlement_total
      )
    end

    # What the marketplace still owes, in the currency it can actually be sent
    # in.
    #
    # A payout settles every position sharing that currency, so a seller who
    # sells in two currencies that settle into one is paid the sum of both
    # rather than either. The figures reconcile — both sides read the same
    # transfer rows — but one position is not one deposit.
    #
    # @return [BigDecimal]
    def balance
      payable - paid
    end

    # @return [Boolean] whether the provider converted this seller's earnings
    def converted?
      settlement_currency != currency
    end

    # Formatted in the settlement currency rather than the sale's, since these
    # are what the account holds.
    %i[payable paid balance].each do |figure|
      define_method(:"display_#{figure}") do
        Spree::Money.new(public_send(figure), currency: settlement_currency)
      end
    end
  end
end
