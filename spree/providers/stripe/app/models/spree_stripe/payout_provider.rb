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
  # retry finds the movement it already made instead of making a second. That
  # holds only while Stripe keeps the record, which is a day — so a call whose
  # answer was lost is reported as ambiguous rather than failed, and core
  # holds the settlement instead of retrying it later on a key that has since
  # expired.
  class PayoutProvider < Spree::PayoutProvider::Base
    # Stripe is looking at the account, and there is nothing the seller can do
    # about it — different words and no button, rather than an invitation to
    # go round the same flow again.
    PENDING_REASONS = %w[under_review requirements.pending_verification platform_paused].freeze

    # Failures that leave the answer with Stripe rather than in the response,
    # so core must not assume the money stayed put.
    #
    # A dropped connection or a timeout may have arrived all the same. An
    # `APIError` is Stripe's own 5xx, which says nothing about whether the
    # request was processed before it broke. An `IdempotencyError` means the
    # key is already held against different parameters, so *something* was
    # recorded under it.
    #
    # `Stripe::APIError` is spelled with a capitalised initialism; there is no
    # `Stripe::ApiError`, and naming one in a rescue raises NameError at the
    # moment the rescue is needed.
    AMBIGUOUS_ERRORS = [
      Stripe::APIConnectionError,
      Stripe::APIError,
      Stripe::IdempotencyError
    ].freeze

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

      # What Stripe says, written down. The stamp is a cache of a webhook that
      # can fail to arrive in either direction — a seller left looking at an
      # unfinished checklist they have finished, or one still counted payable
      # after Stripe withdrew it. Recording the answer keeps the workflows
      # that gate money on the column honest without their asking.
      stamp = account.payouts_enabled ? (seller.payouts_enabled_at || Time.current) : nil

      if seller.payouts_enabled_at != stamp
        became_payable = stamp.present?
        seller.update!(payouts_enabled_at: stamp)
        # Whatever they earned while we believed they could not be paid. The
        # webhook normally does this; noticing here covers the case where it
        # never arrived, which is otherwise money sitting pending forever.
        Spree::SellerTransfers::ExecutePendingJob.perform_later(seller.id) if became_payable
      end

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
      # Nothing to move. A seller whose commission met their sale earns zero,
      # which is a true ledger row and an amount Stripe refuses — asking it to
      # would park the row and have the retry job ask again forever.
      return complete_without_sending(seller_transfer) if minor_units(seller_transfer).zero?

      seller = seller_transfer.seller
      gateway = gateway_for(seller.store)
      source_charge = source_charge_for(seller_transfer, gateway)
      amount, currency = transfer_figures(seller_transfer, gateway, source_charge)
      # A share of the settled charge can round to nothing — a sub-cent earning
      # converted into a currency worth more per minor unit. Stripe refuses a
      # zero amount, so the row is closed as settled for nothing rather than
      # sent to be refused on every retry.
      if amount.zero?
        seller_transfer.update!(status: 'completed', settled_amount: 0, settled_currency: currency.upcase)
        return seller_transfer
      end

      transfer = Stripe::Transfer.create(
        {
          amount: amount,
          currency: currency,
          destination: seller.payout_account_reference(self.class),
          # Funds the transfer from the customer's own charge, so it settles
          # with that charge rather than out of the platform's balance.
          source_transaction: source_charge,
          # Stripe refuses a second group on a transfer drawn from a charge
          # that already carries one, and the intent is grouped at checkout.
          transfer_group: (transfer_group_for(seller_transfer) if source_charge.blank?),
          metadata: {
            spree_seller_transfer_id: seller_transfer.id,
            spree_order_number: seller_transfer.order.number
          },
          # What the seller's own account received. An account settles in its
          # own currency and Stripe converts on the way in, so the sale's
          # figure is not the payable one.
          expand: ['destination_payment.balance_transaction']
        }.compact,
        gateway.api_options.merge(idempotency_key: idempotency_key(seller_transfer))
      )

      seller_transfer.update!(
        { status: 'completed', reference: transfer.id }.merge(settlement_of(transfer))
      )
      seller_transfer
    rescue *AMBIGUOUS_ERRORS => e
      # As with a settlement: the transfer may have been made before the answer
      # was lost, so core parks the earning rather than offering it to the
      # retry job, which would send the same money again once Stripe has
      # forgotten the key.
      raise Spree::Core::AmbiguousGatewayError, e.message
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
    rescue *AMBIGUOUS_ERRORS => e
      # Nobody knows whether the money moved. The request may have reached
      # Stripe and created the payout before the answer was lost, so core must
      # not put these earnings back on the pile — the idempotency key stops a
      # retry only while Stripe keeps the record, which is a day, and sweeps
      # run on a merchant's schedule rather than inside one.
      raise Spree::Core::AmbiguousGatewayError, e.message
    end

    # What the seller's account can send today, in the currency asked for.
    #
    # A transfer is credited on fulfilment but funded by the customer's charge,
    # so the money reaches the seller's balance only when that charge settles.
    # Asking Stripe is the documented way to know the difference; a payout for
    # more than the available balance is refused outright.
    #
    # Zero when the account holds nothing in this currency — including a
    # cross-border seller whose account settles in its own currency and can
    # therefore never pay out what the ledger denominated the sale in.
    #
    # @return [BigDecimal]
    def available_payout(seller, currency)
      gateway = gateway_for(seller.store)
      account_id = seller.payout_account_reference(self.class)
      raise Spree::Core::GatewayError, 'Seller holds no Stripe account' if account_id.blank?

      balance = Stripe::Balance.retrieve({}, gateway.api_options.merge(stripe_account: account_id))
      wanted = currency.to_s.downcase
      minor = balance.available.select { |entry| entry.currency == wanted }.sum(&:amount)

      SpreeStripe::Units.from_stripe(minor, currency)
    rescue *AMBIGUOUS_ERRORS => e
      # The sweep must not read silence as "nothing to send" and settle a
      # smaller batch than the seller is owed, nor as "no limit" and ask for
      # everything again. Neither is knowable, so nothing is paid this period.
      raise Spree::Core::AmbiguousGatewayError, e.message
    end

    # Pulls a seller's share of a refund back from their connected account.
    #
    # Reverses the transfer that paid the earning, by the reversal's amount,
    # so the money returns to the platform that refunded the customer. A
    # seller who has already been paid out is left with a negative Stripe
    # balance, which their next earnings make up before anything more is paid
    # out to them.
    #
    # The reversal waits until its earning has reached Stripe: until then
    # there is no transfer to take from. It is left pending, and the
    # pending-transfers job asks again once the earning is sent.
    #
    # A retry first looks for a reversal an earlier attempt already made, so
    # the seller is never charged twice for one refund.
    def reverse!(seller_transfer)
      return complete_without_sending(seller_transfer) if minor_units(seller_transfer).zero?

      earning = seller_transfer.reversed_from
      raise Spree::Core::GatewayError, 'Reversal has no earning to take back from' if earning.nil?
      # Never sent, so nothing reached the seller's account.
      return complete_without_sending(seller_transfer) if earning.failed?
      return seller_transfer unless earning.completed?

      # Settled for nothing (see #transfer!), so there is nothing to take back.
      if earning.reference.blank? && earning.settled_amount.to_d.zero?
        return complete_taking_nothing(seller_transfer, earning)
      end

      # Confirmed without a transfer to point at — settled by hand, say. Only
      # a person can say where that money is.
      if earning.reference.blank?
        raise Spree::Core::AmbiguousGatewayError, 'The earning has no Stripe transfer to reverse'
      end

      api_options = gateway_for(seller_transfer.seller.store).api_options
      reversal = made_reversal(earning, seller_transfer, api_options)
      taken = seller_transfer.amount.abs
      # An earlier attempt made it but never recorded it, and it may have been
      # capped below the row's share — so record what it actually took.
      taken = taken_by(reversal, earning, seller_transfer, api_options) if reversal

      unless reversal
        # In the transfer's own currency, which is not the sale's when the
        # earning was drawn from a charge that settled in another one.
        amount, taken = reversal_figures(earning, seller_transfer, api_options)
        return complete_taking_nothing(seller_transfer, earning) if amount.zero?

        reversal = Stripe::Transfer.create_reversal(
          earning.reference,
          {
            amount: amount,
            metadata: {
              spree_seller_transfer_id: seller_transfer.id,
              spree_order_number: seller_transfer.order.number
            }
          },
          api_options.merge(idempotency_key: idempotency_key(seller_transfer))
        )
      end

      # The earning may have been sent after this row was written, and only
      # then learned the currency it settled in. The settlement records the
      # share Stripe actually took back, which is less than the row's when the
      # transfer had less left to give.
      seller_transfer.update!(
        { status: 'completed', reference: reversal.id }.merge(earning.reversal_settlement(taken))
      )
      seller_transfer
    rescue *AMBIGUOUS_ERRORS => e
      # The reversal may have been made before the answer was lost, so core
      # parks it rather than taking the money back twice.
      raise Spree::Core::AmbiguousGatewayError, e.message
    end

    private

    # What landed on the seller's account, read off the balance transaction of
    # the payment the transfer created there. Empty when Stripe did not expand
    # it, which leaves the ledger reading the earned figures rather than
    # inventing a settlement.
    #
    # @return [Hash]
    def settlement_of(transfer)
      balance_transaction = transfer.try(:destination_payment).try(:balance_transaction)
      return {} if balance_transaction.blank? || balance_transaction.try(:currency).blank?

      {
        settled_amount: SpreeStripe::Units.from_stripe(balance_transaction.amount, balance_transaction.currency),
        settled_currency: balance_transaction.currency.upcase
      }
    end

    def complete_without_sending(seller_transfer)
      seller_transfer.update!(status: 'completed')
      seller_transfer
    end

    # A reversal with nothing left to take: closed without asking Stripe, which
    # refuses a zero amount, and recorded as taking nothing from the seller.
    def complete_taking_nothing(seller_transfer, earning)
      seller_transfer.update!({ status: 'completed' }.merge(earning.reversal_settlement(0)))
      seller_transfer
    end

    # The reversal an earlier attempt made but never recorded — the row failed
    # to save, or the process stopped first. Found by the row it names, since
    # the idempotency key that would also stop a second one lasts only a day.
    #
    # A failed lookup moved no money, so it is a refusal the retry job can
    # repeat rather than an outcome nobody knows.
    def made_reversal(earning, seller_transfer, api_options)
      reversals = Stripe::Transfer.list_reversals(earning.reference, { limit: 100 }, api_options)
      reversals.auto_paging_each.find do |reversal|
        reversal.metadata['spree_seller_transfer_id'] == seller_transfer.id.to_s
      end
    rescue Stripe::StripeError => e
      raise Spree::Core::GatewayError, e.message
    end

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
      SpreeStripe::Units.to_stripe(record.amount.abs, record.currency, payout: true)
    end

    # Ties transfers paid from the platform balance to the checkout they
    # settle — a split checkout's sellers share their group's number.
    def transfer_group_for(seller_transfer)
      seller_transfer.order.order_group&.number || seller_transfer.order.number
    end

    # The amount and currency to ask Stripe for.
    #
    # A charge is taken in the order's currency, but it lands on the platform
    # in the platform's own settlement currency, and a transfer drawn from it
    # (`source_transaction`) must be made in that currency: "The currency of
    # source_transaction's balance transaction (usd) must be the same as the
    # transfer currency (gbp)". So when the two differ the earning is expressed
    # in the settlement currency at the rate Stripe itself applied to the
    # charge — its share of the charge's balance transaction. Spree holds no
    # exchange rates and invents none. The seller's row keeps the currency it
    # was owed in; what their account received is recorded from the transfer.
    #
    # @return [Array(Integer, String)] minor units and lowercase currency code
    def transfer_figures(seller_transfer, gateway, source_charge)
      amount = minor_units(seller_transfer)
      currency = seller_transfer.currency.downcase
      return [amount, currency] if source_charge.blank?

      charge = retrieve_charge(source_charge, gateway.api_options)
      balance_transaction = charge.try(:balance_transaction)
      settlement = balance_transaction.try(:currency).to_s.downcase
      return [amount, currency] if settlement.blank? || settlement == currency
      # The balance transaction is what was captured, which for a partly
      # captured charge is less than the amount authorised.
      captured = charge.try(:amount_captured).to_i.positive? ? charge.amount_captured.to_i : charge.amount.to_i
      # Without the charge in the sale's currency there is nothing to take a
      # share of; let Stripe answer as it would have.
      return [amount, currency] unless charge.currency.to_s.downcase == currency && captured.positive?

      # Never more than the charge settled for — an earning larger than what
      # was captured would otherwise ask for a transfer Stripe refuses on
      # every retry.
      share = [prorate(amount, balance_transaction.amount, captured), balance_transaction.amount.to_i].min
      [SpreeStripe::Units.floor_to_step(share, settlement, payout: true), settlement]
    end

    # What a reversal asks Stripe to take back. Stripe reads a reversal's
    # amount in the currency of the transfer it reverses, and a transfer drawn
    # from a charge that settled in another currency was made in that one
    # (see #transfer_figures) — so the sale's figure would claw back too little,
    # or more than the transfer holds. The reversal's share of the earning is
    # taken of what the transfer actually moved instead, and never more than
    # the transfer still has to give back.
    #
    # @return [Array(Integer, BigDecimal)] minor units to send, in the
    #   transfer's currency, and the part of the sale-currency row that is
    def reversal_figures(earning, seller_transfer, api_options)
      amount = minor_units(seller_transfer)
      part = seller_transfer.amount.abs
      transfer = Stripe::Transfer.retrieve(earning.reference, api_options)
      return [amount, part] if transfer.currency.to_s.downcase == seller_transfer.currency.to_s.downcase

      earned = minor_units(earning)
      return [amount, part] unless earned.positive?

      share = prorate(amount, transfer.amount, earned)
      left = [transfer.amount.to_i - transfer.amount_reversed.to_i, 0].max
      sent = SpreeStripe::Units.floor_to_step(share.clamp(0, left), transfer.currency, payout: true)
      return [0, 0.to_d] if sent.zero?

      [sent, transfer_share(earning, sent, transfer, part)]
    rescue Stripe::StripeError => e
      # A look-up moves no money, so it is a refusal the retry job can repeat.
      raise Spree::Core::GatewayError, e.message
    end

    # The part of the sale-currency row a reversal Stripe already made stands
    # for: its own amount when it is in the sale's currency, otherwise its share
    # of the transfer it came from. Never more than the row.
    #
    # @return [BigDecimal]
    def taken_by(reversal, earning, seller_transfer, api_options)
      part = seller_transfer.amount.abs
      sent = reversal.try(:amount)
      return part if sent.nil?

      currency = reversal.try(:currency).to_s
      taken = if currency.blank? || currency.casecmp?(seller_transfer.currency.to_s)
                SpreeStripe::Units.from_stripe(sent, seller_transfer.currency)
              else
                transfer = Stripe::Transfer.retrieve(earning.reference, api_options)
                return transfer_share(earning, sent, transfer, part)
              end
      [taken, part].min
    rescue Stripe::StripeError => e
      raise Spree::Core::GatewayError, e.message
    end

    # The part of the sale-currency earning that `sent` minor units of its
    # transfer stand for, never more than the reversal row. Used both when a
    # reversal is made and when a retry finds one already made, so the same
    # Stripe reversal is always recorded as the same figure.
    #
    # @return [BigDecimal]
    def transfer_share(earning, sent, transfer, part)
      return part unless transfer.amount.to_i.positive?

      [earning.amount.abs * sent.to_d / transfer.amount.to_d, part].min
    end

    # The charge with the balance transaction that says what it settled for.
    #
    # A failed look-up moved no money, so it is a refusal the retry job can
    # repeat. Left to the rescue in #transfer!, a timeout here would be taken
    # for an ambiguous transfer and park the earning where no retry reaches it.
    def retrieve_charge(charge_id, api_options)
      Stripe::Charge.retrieve({ id: charge_id, expand: ['balance_transaction'] }, api_options)
    rescue Stripe::StripeError => e
      raise Spree::Core::GatewayError, e.message
    end

    # `part` of `whole` minor units, as a share of `of`, in exact decimal
    # arithmetic. Rounded down so the shares drawn from one charge or one
    # transfer never add up to more than it holds.
    #
    # @return [Integer]
    def prorate(part, whole, of)
      (part.to_d * whole.to_d / of.to_d).round(0, BigDecimal::ROUND_DOWN).to_i
    end

    # The charge that paid for this order, so Stripe can fund the transfer from
    # it. Nil when the order was not paid by card — a store-credit sale has no
    # charge to draw on, and Stripe then funds from the platform balance.
    # Stripe funds a transfer from a *charge*, and `response_code` holds the
    # payment intent rather than the charge it produced — sending that would
    # fail every card-funded transfer on an id Stripe cannot use. The charge
    # is recorded on the payment when its session completes.
    def source_charge_for(seller_transfer, gateway)
      payment = seller_transfer.order.settlement_payments.valid.completed.
                find { |candidate| candidate.payment_method_id == gateway.id }

      payment&.metadata&.dig('stripe_charge_id')
    end
  end
end
