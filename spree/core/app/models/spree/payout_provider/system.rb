module Spree
  module PayoutProvider
    # The built-in provider: it keeps the books and moves no money.
    #
    # This is what a marketplace runs before it connects anything. Sellers
    # accrue earnings as their orders ship, those earnings batch into
    # settlements on schedule, and the operator sees exactly what is owed to
    # whom — then pays it by bank transfer and marks the settlement complete.
    #
    # An earning is confirmed immediately, because with no remote party there
    # is nothing to confirm: the seller has shipped and the marketplace holds
    # their money. A settlement, by contrast, stays pending until somebody says
    # it was actually sent — that is a claim about the outside world, and only
    # a person can make it here.
    class System < Base
      def transfer!(seller_transfer)
        seller_transfer.update!(status: 'completed')
        seller_transfer
      end

      # Deliberately does nothing. The payout waits in the operator's queue
      # until it is marked paid — recording it as settled here would assert a
      # bank transfer nobody has made.
      def pay!(seller_payout)
        seller_payout
      end

      # The ledger row is the whole reversal. Nothing was ever sent, so
      # nothing has to come back.
      def reverse!(seller_transfer)
        seller_transfer.update!(status: 'completed')
        seller_transfer
      end
    end
  end
end
