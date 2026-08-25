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

      # What a ledger row records as having moved its money.
      #
      # The full class name rather than its last segment: every provider gem
      # calls its class `PayoutProvider`, so the leaf alone identifies nothing
      # and would make two gems' rows indistinguishable — including to the
      # unique index on (provider, reference) that guards retries.
      #
      # @return [String]
      def self.provider_key
        name
      end

      # The key a seller's account with this provider is recorded under, as a
      # {Spree::ExternalReference} system.
      #
      # Underscored rather than the class name, because a system key is a
      # lowercase identifier by contract — and where a provider gem also ships
      # a {Spree::Integration}, the convention is that the two agree, so a
      # connector, its references and its settings page name the same thing.
      #
      # @return [String]
      def self.reference_system
        name.demodulize.underscore
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

      # Where a seller goes to give this provider what it needs before it will
      # pay them — bank details, identity documents, whatever it asks.
      #
      # Nil when there is nowhere to send them, which is the built-in
      # provider's answer: an operator paying by bank transfer collects those
      # details themselves, so the requirement is met by the operator marking
      # it so rather than by the seller going anywhere.
      #
      # Implementations mint the link per call — hosted onboarding links are
      # short-lived and single-use by design, so one is never stored.
      #
      # @param seller [Spree::Seller]
      # @param refresh_url [String] where the provider sends a seller whose
      #   link expired before they finished
      # @param return_url [String] where it sends them when they are done
      # @return [String, nil]
      def onboarding_url(_seller, refresh_url:, return_url:)
        nil
      end

      # Whether this provider will now accept money for a seller. Asked of the
      # provider rather than read off the seller, because only the provider
      # knows — and its answer can change without anything happening in Spree.
      #
      # @param seller [Spree::Seller]
      # @return [Boolean]
      def onboarded?(seller)
        !self.class.requires_payout_account? || seller.payouts_enabled?
      end

      # Why a seller is not payable yet, in terms any provider can answer.
      #
      # Deliberately a state rather than a list of outstanding fields. What
      # each provider is missing is its own vocabulary — field paths, document
      # codes, review case ids — and none of it survives translation into a
      # shared one. The reference provider goes further and asks not to be
      # enumerated at all: its guidance is to send the seller back to the
      # hosted flow, which already knows what it wants, rather than to
      # reimplement its form badly.
      #
      # What a seller actually needs from this is which of three things is
      # true, because each deserves different words and a different button:
      #
      #   nil       — nothing to say; they are payable, or no provider asks
      #   :action   — the provider wants something from them
      #   :pending  — the provider is checking, and nobody can hurry it
      #   :rejected — the provider has refused them
      #
      # A provider may add a sentence of its own through {#onboarding_message},
      # which is best-effort and unlocalized.
      #
      # @param _seller [Spree::Seller]
      # @return [Symbol, nil]
      def onboarding_state(_seller)
        nil
      end

      # A provider's own words about what is outstanding, when it has any.
      #
      # Best-effort and **unlocalized** — providers write these in English and
      # say so. Shown as supporting detail beside copy the panel has
      # translated, never as the only explanation a seller gets.
      #
      # @param _seller [Spree::Seller]
      # @return [String, nil]
      def onboarding_message(_seller)
        nil
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
