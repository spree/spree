module SpreeStripe
  # Pays sellers through Stripe Connect.
  #
  # The marketplace charges the customer on its own account, then moves each
  # seller's share to their connected account as the goods go out. Two things
  # make that work and are worth naming:
  #
  # **The transfer names the charge that funds it.** Stripe's `source_transaction`
  # ties a transfer to a specific charge, so the money moves as soon as that
  # charge settles rather than waiting for the platform's own balance to cover
  # it — a marketplace should not have to float its sellers.
  #
  # **Settlement is Stripe's own schedule.** Once money is on a connected
  # account, Stripe pays it out to the seller's bank on the schedule configured
  # for that account. So {#pay!} does not send anything: it records what Stripe
  # is going to do, and a webhook confirms when it did.
  #
  # Every call carries an idempotency key derived from the ledger row, so a
  # retry after a timeout finds the movement it already made instead of making
  # a second.
  class PayoutProvider < Spree::PayoutProvider::Base
    # Stripe is looking at the account, and there is nothing the seller can do
    # about it — different words and no button, rather than an invitation to
    # go round the same flow again.
    PENDING_REASONS = %w[under_review requirements.pending_verification platform_paused].freeze

    def self.display_name
      'Stripe Connect'
    end

    # Matches the Stripe gateway's own integration key, so a seller's Connect
    # account is filed under the same name the rest of the gem uses.
    def self.reference_system
      'stripe'
    end

    # A seller must hold a connected account before anything can be sent to
    # them, so core will not credit one who does not.
    def self.requires_payout_account?
      true
    end

    def self.available_for_store?(store)
      gateway_for(store).present?
    end

    # The store's Stripe gateway — the account that charges customers, and so
    # the account that pays sellers.
    #
    # @return [SpreeStripe::Gateway, nil]
    def self.gateway_for(store)
      store.payment_methods.active.find { |method| method.is_a?(SpreeStripe::Gateway) }
    end

    # Stripe's own hosted onboarding, where the seller gives Stripe their
    # identity and bank details directly — so the marketplace never handles
    # them and inherits Stripe's checks rather than building its own.
    def onboarding_url(seller, refresh_url:, return_url:)
      gateway_for(seller.store).create_connect_account_link(
        seller: seller,
        refresh_url: refresh_url,
        return_url: return_url
      )
    rescue Stripe::StripeError => e
      # Core knows nothing about Stripe's exceptions, and a seller asking to
      # set up their payouts should be told what went wrong rather than shown
      # a crash. The provider contract speaks GatewayError.
      raise Spree::Core::GatewayError, e.message
    end

    # Asked of Stripe rather than read from `payouts_enabled_at`.
    #
    # That column is a cache of what a webhook last told us, and a webhook is
    # a thing that can fail to arrive — an endpoint not yet registered, a
    # delivery dropped, a local tunnel that was not running. A seller who has
    # finished onboarding then sits looking at a checklist that says they have
    # not, while Stripe has been ready to pay them for hours.
    #
    # The account is fetched once per instance either way, since answering why
    # a row is incomplete needs it too.
    def onboarded?(seller)
      account = retrieve_account(seller)
      return seller.payouts_enabled? if account.nil?

      account.payouts_enabled
    end

    # Which of the three things is true, read off the account itself.
    #
    # Stripe's `disabled_reason` is the account-level answer, and its values
    # divide cleanly: some mean the seller must do something, some mean Stripe
    # is looking and nobody can hurry it, and some mean Stripe has said no.
    # The per-field requirement list is deliberately not read — Stripe's own
    # guidance for Express is to send the seller back to hosted onboarding
    # rather than enumerate what it wants, since that flow already knows.
    def onboarding_state(seller)
      account = retrieve_account(seller)
      return nil if account.nil? || account.payouts_enabled

      reason = account.requirements&.disabled_reason.to_s
      return :rejected if reason.start_with?('rejected.') || reason == 'listed'
      return :pending if PENDING_REASONS.include?(reason)

      :action
    end

    # Stripe writes these itself, in English, and says so — shown as detail
    # beside translated copy, never instead of it. Only the failures have one:
    # a field simply not provided yet has no error and nothing to say.
    def onboarding_message(seller)
      account = retrieve_account(seller)
      return nil if account.nil?

      Array(account.requirements&.errors).filter_map { |error| error[:reason] }.first
    end

    # Moves one seller's earning to their connected account.
    def transfer!(seller_transfer)
      seller = seller_transfer.seller
      gateway = gateway_for(seller.store)

      transfer = Stripe::Transfer.create(
        {
          amount: minor_units(seller_transfer),
          currency: seller_transfer.currency.downcase,
          destination: seller.payout_account_reference(self.class),
          # Funds the transfer from the customer's own charge, so it settles
          # with that charge rather than out of the platform's balance.
          source_transaction: source_charge_for(seller_transfer, gateway),
          transfer_group: seller_transfer.order.order_group&.number || seller_transfer.order.number,
          metadata: {
            spree_seller_transfer_id: seller_transfer.id,
            spree_order_number: seller_transfer.order.number
          }
        }.compact,
        gateway.api_options.merge(idempotency_key: idempotency_key(seller_transfer))
      )

      seller_transfer.update!(status: 'completed', reference: transfer.id)
      seller_transfer
    end

    # Sends a settlement from the seller's connected account to their bank.
    #
    # Spree decides when — connected accounts are created on a manual schedule
    # precisely so Stripe is not also paying out on one of its own. Two clocks
    # on one relationship do not compose: honour both and a monthly seller
    # waits up to two months, honour neither and the operator's setting is a
    # decoration.
    #
    # Made as the connected account rather than as the platform, because the
    # money being moved is the seller's own balance. The payout stays pending
    # until `payout.paid` says it reached the bank — a settlement is a claim
    # about the outside world whoever makes it.
    def pay!(seller_payout)
      seller = seller_payout.seller
      gateway = gateway_for(seller.store)
      account_id = seller.payout_account_reference(self.class)
      raise Spree::Core::GatewayError, 'Seller holds no Stripe account' if account_id.blank?

      payout = Stripe::Payout.create(
        {
          amount: minor_units(seller_payout),
          currency: seller_payout.currency.downcase,
          metadata: { spree_seller_payout_id: seller_payout.id }
        },
        gateway.api_options.merge(stripe_account: account_id, idempotency_key: idempotency_key(seller_payout))
      )

      # Stored now rather than waiting for the webhook, so the confirmation
      # matches on Stripe's own id instead of guessing by amount.
      seller_payout.update!(reference: payout.id)
      seller_payout
    end

    # Pulls a seller's money back after a refund.
    #
    # Ledger-only in open source: the row is written either way, so the books
    # stay correct, but reversing the Stripe transfer — and netting a negative
    # balance against future earnings — is where a marketplace needs the money
    # operations that Enterprise provides.
    def reverse!(seller_transfer)
      seller_transfer.update!(status: 'completed')
      seller_transfer
    end

    private

    # Nil rather than raising: a checklist row asking why it is incomplete
    # must not take the page down because Stripe is unreachable.
    def retrieve_account(seller)
      account_id = seller.payout_account_reference(self.class)
      return nil if account_id.blank?

      @retrieved_accounts ||= {}
      @retrieved_accounts[account_id] ||= Stripe::Account.retrieve(
        account_id, gateway_for(seller.store).api_options
      )
    rescue Stripe::StripeError => e
      Rails.error.report(e, handled: true, context: { seller_id: seller.id }, source: 'spree_stripe')
      nil
    end

    def gateway_for(store)
      self.class.gateway_for(store) ||
        raise(Spree::Core::GatewayError, 'No active Stripe payment method on this store')
    end

    def minor_units(record)
      Spree::Money::Rounding.to_minor_units(record.amount.abs, record.currency)
    end

    # The charge that paid for this order, so Stripe can fund the transfer from
    # it. Nil when the order was not paid by card — a store-credit sale has no
    # charge to draw on, and Stripe then funds from the platform balance.
    def source_charge_for(seller_transfer, gateway)
      payment = seller_transfer.order.settlement_payments.valid.completed.
                find { |candidate| candidate.payment_method_id == gateway.id }

      payment&.response_code
    end
  end
end
