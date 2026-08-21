module Spree
  module PayoutProvider
    # Contract for whatever actually moves money to a seller.
    #
    # Core records both levels of the ledger for every marketplace — what each
    # seller earned as their orders shipped, and what has been settled to them.
    # A provider decides whether that money moves on its own: the built-in one
    # records and leaves the operator to pay by bank, while a connected
    # provider performs the transfer and reports back.
    #
    # Three verbs, one per thing that can happen to money:
    #
    #   transfer! — a seller earned on a fulfilled order (level one)
    #   pay!      — their accrued earnings are settled (level two)
    #   reverse!  — a refund takes some of an earning back
    #
    # Every verb must be **idempotent**, keyed on the record's prefixed id: a
    # crash between the remote call and the local commit is retried, and a
    # retry must find the movement it already made rather than make a second.
    #
    # Providers are stateless and constructed without arguments, as tax and
    # delivery-rate providers are; anything request-specific arrives as an
    # argument.
    class Base
      # The name a merchant sees when choosing how sellers are paid.
      #
      # @return [String]
      def self.display_name
        name.demodulize.titleize
      end

      # Whether this provider can be selected for a store — an external one
      # overrides it to require connected credentials.
      #
      # @param store [Spree::Store]
      # @return [Boolean]
      def self.available_for_store?(_store)
        true
      end

      # Whether this provider needs sellers to hold an account with it before
      # they can be paid. A marketplace settling by bank transfer does not; a
      # connected provider does, and core will not credit a seller it cannot
      # pay through one.
      #
      # @return [Boolean]
      def self.requires_payout_account?
        false
      end

      # Credits a seller for one fulfilled order.
      #
      # @param seller_transfer [Spree::SellerTransfer]
      # @return [Spree::SellerTransfer]
      def transfer!(_seller_transfer)
        raise NotImplementedError
      end

      # Settles a seller's accrued earnings.
      #
      # @param seller_payout [Spree::SellerPayout]
      # @return [Spree::SellerPayout]
      def pay!(_seller_payout)
        raise NotImplementedError
      end

      # Takes back part of an earning after a refund.
      #
      # The ledger row is written by core either way — the books stay correct
      # in every tier — so a provider that cannot pull money back implements
      # this as a no-op rather than refusing.
      #
      # @param seller_transfer [Spree::SellerTransfer] the reversal row
      # @return [Spree::SellerTransfer]
      def reverse!(_seller_transfer)
        raise NotImplementedError
      end

      # The key a provider passes to its own API so a retried call cannot move
      # money twice.
      #
      # @param record [Spree::SellerTransfer, Spree::SellerPayout]
      # @return [String]
      def idempotency_key(record)
        "spree-#{record.prefixed_id}"
      end
    end
  end
end
