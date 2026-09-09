module Spree
  module Purchases
    # How much of a purchase has to be paid before it can be placed and
    # dispatched.
    #
    # The whole total, always, in open source: a buyer pays for what they are
    # taking. The class exists so that arrangements which collect only part of
    # it — a deposit up front with the balance owed later, net terms — can be
    # honoured without patching the half-dozen places that decide whether
    # enough money has arrived.
    #
    # Replace it through {Spree::Dependencies}, the same way a rate provider
    # or a workflow is replaced:
    #
    #   Spree::Dependencies.purchase_amount_due_at_checkout_service =
    #     'MyApp::AmountDueOnDepositTerms'
    #
    # A replacement answers a decimal in the purchase's own currency, and must
    # never answer more than the total — asking for more than the goods are
    # worth is refused at checkout rather than collected.
    #
    # Deposits and net terms are designed in
    # docs/plans/6.0-6.1-b2b-payment-terms.md; nothing in open source resolves
    # them, so this is the whole implementation here.
    class AmountDueAtCheckout
      # @param purchase [Spree::Cart, Spree::Order]
      # @return [BigDecimal]
      def call(purchase:)
        purchase.total.to_d
      end
    end
  end
end
