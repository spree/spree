module Spree
  module GiftCards
    # Puts a gift card's balance onto an order. The card is not spent here —
    # it is drawn against: a store credit is issued for whatever the card can
    # cover, a payment is created from it, and the card's used amount rises to
    # match. Spree::GiftCards::Redeem records the outcome once the order is
    # placed.
    #
    # A workflow rather than a service because the eligibility rules are the
    # kind a store overrides — who may spend a card, on what, and up to how
    # much — and because it writes several records that must stand or fall
    # together.
    #
    # A card already sitting on another open cart is released rather than
    # refused. That hold is not a payment — nobody has been charged — so
    # whoever presents the code now takes it, and whoever completes an order
    # first keeps it. Refusing instead would strand the balance whenever the
    # other cart is unreachable (another device, a guest session), because
    # holds never expire on their own. Override the +release_holds+ hook to
    # refuse instead.
    class Apply < Spree::Workflow
      hooks :validate, :release_holds, :after_apply

      # Carts and draft orders whose hold on the card this apply released.
      # @return [Array<Spree::Cart, Spree::Order>]
      attr_reader :released_holds

      attr_reader :store_credit, :payment

      # @param gift_card [Spree::GiftCard]
      # @param order [Spree::Order]
      # @return [Spree::ServiceModule::Result] value is the reloaded order
      def perform(gift_card:, order:)
        super

        step :ensure_applicable
        run_hooks :validate

        # One transaction so a refused release rolls back the ones that
        # already succeeded. Holds are released BEFORE the card is locked:
        # Spree::GiftCards::Remove locks its record and then the card, so
        # taking the card first here would invert that order and deadlock
        # against any concurrent remove of the same card.
        ApplicationRecord.transaction do
          # Every record this workflow touches — the target and each hold —
          # is locked in one id-ordered pass before anything takes the
          # gift-card lock. One global order, so two applies whose targets
          # are each other's holds queue instead of crossing; and never
          # card-then-record, which is the order Spree::GiftCards::Remove
          # uses and which the transaction would otherwise keep.
          step :lock_affected_records
          step :release_open_holds
          run_hooks :release_holds

          order.with_lock do
            step :lock_gift_card
            step :ensure_amount_available
            step :issue_store_credit
            step :draw_down_gift_card
            step :create_payment
            step :recalculate_order
            run_hooks :after_apply
          end
        end

        success(order.reload)
      end

      private

      def ensure_applicable
        # A gift card and a store credit are two ways of paying from a
        # balance; mixing them on one order is not supported.
        failure(order, :gift_card_using_store_credit_error) if order.using_store_credit?
        failure(order, :gift_card_mismatched_currency) if gift_card.currency != order.currency

        # The store controllers check these before they get here, but this
        # workflow is the shared entry point every caller now uses, so a card
        # that cannot be spent is refused here rather than only at the edge.
        failure(order, :gift_card_expired) if gift_card.expired?
        failure(order, :gift_card_already_redeemed) if gift_card.redeemed?
        failure(order, :gift_card_canceled) if gift_card.canceled?

        return if gift_card.customer.blank?

        # A card issued to someone is theirs alone.
        failure(order, :gift_card_customer_not_logged_in) if order.customer.blank?
        failure(order, :gift_card_mismatched_customer) if gift_card.customer != order.customer
      end

      def lock_gift_card
        gift_card.lock!
      end

      # Locks the target together with every hold, ordered by id within each
      # class so concurrent applies acquire them in the same sequence.
      def lock_affected_records
        @holds_to_release = gift_card.open_holds(except: order)

        (@holds_to_release + [order]).group_by(&:class).each do |klass, records|
          klass.where(id: records.map(&:id)).order(:id).lock.to_a
        end

        order.reload
      end

      # Runs before the balance is read, so the released amount is available
      # to this order. Releasing is all or nothing with the apply itself: a
      # refused release fails the whole workflow, which rolls back the ones
      # that did succeed. Emptying one shopper's cart and then not spending
      # the balance would be the worst of both outcomes.
      def release_open_holds
        @released_holds = []
        return if @holds_to_release.blank?

        @holds_to_release.each { |hold| release_hold(hold) }

        gift_card.reload
      end

      # Re-reads the hold under its own lock before removing anything. The
      # list was gathered outside that lock, so by now the other shopper may
      # have taken this card off, swapped a different one on, or started a
      # checkout — and Remove detaches whatever card the record carries at the
      # time, not the one we meant. A hold that has moved on is skipped, which
      # includes one that claimed completion in the window: its totals are
      # fixed and money may already be at the gateway.
      def release_hold(hold)
        hold.with_lock do
          hold.reload
          next unless hold.gift_card_id == gift_card.id
          next if hold.completed?
          next if claimed_since_snapshot?(hold)

          result = Spree.gift_card_remove_workflow.call(order: hold)

          if result.success?
            @released_holds << hold
          else
            report_unreleased_hold(hold, result)
            failure(order, :gift_card_held_by_another_order)
          end
        end
      end

      # Mirrors Spree::GiftCard#open_holds, which excludes a claimed cart and
      # a draft order whose originating cart is claimed.
      def claimed_since_snapshot?(hold)
        return hold.completion_claimed? if hold.is_a?(Spree::Cart)

        hold.cart&.reload&.completion_claimed? || false
      end

      def report_unreleased_hold(hold, result)
        Rails.error.report(
          Spree::Core::GiftCardHoldReleaseFailed.new(
            "Gift card #{gift_card.id} could not be released from #{hold.class.name} #{hold.id}: #{result.error}"
          ),
          handled: true,
          context: { order_id: order.id, gift_card_id: gift_card.id, hold_id: hold.id, hold_type: hold.class.name },
          source: 'spree.core'
        )
      end

      def ensure_amount_available
        # Releasing a hold changed amount_remaining, so drop anything computed
        # before that — a stale positive would let a zero balance reach
        # issue_store_credit and raise there instead of failing here.
        @amount = nil
        return if amount.positive? || order.total.zero?

        # Distinguish a spent card from one whose balance is briefly locked
        # up elsewhere — the customer can retry the second, not the first.
        failure(order, :gift_card_held_by_another_order) if held_elsewhere?
        failure(order, :gift_card_no_amount_remaining)
      end

      # Read fresh rather than from the snapshot the release worked from. A
      # hold created since then was never offered for release, so reporting
      # the card as spent would be wrong — the balance is recoverable and the
      # customer should be told to retry.
      def held_elsewhere?
        gift_card.holds_being_completed(except: order).any? ||
          gift_card.open_holds(except: order).any?
      end

      def amount
        @amount ||= [gift_card.amount_remaining, order.total].min
      end

      def issue_store_credit
        @store_credit = gift_card.store_credits.create!(
          store: order.store,
          customer: order.customer,
          amount: amount,
          currency: order.currency,
          originator: gift_card,
          action_originator: gift_card
        )
      end

      def draw_down_gift_card
        gift_card.amount_used += amount
        gift_card.save!
      end

      def create_payment
        order.update!(gift_card: gift_card)
        @payment = order.payments.create!(
          source: store_credit,
          payment_method: store_credit_payment_method,
          amount: amount,
          status: 'checkout',
          response_code: store_credit.generate_authorization_code
        )
      end

      def recalculate_order
        order.recalculate_totals!
      end

      def store_credit_payment_method
        @store_credit_payment_method ||= begin
          payment_method = order.store.payment_methods.find_or_initialize_by(
            type: 'Spree::PaymentMethod::StoreCredit'
          )
          payment_method.name ||= Spree.t(:store_credit_name)
          payment_method.active = true
          payment_method.save! if payment_method.new_record?
          payment_method
        end
      end
    end
  end
end
