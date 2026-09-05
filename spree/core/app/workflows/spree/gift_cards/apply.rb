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

        order.with_lock do
          step :lock_gift_card
          step :release_open_holds
          run_hooks :release_holds
          step :ensure_amount_available
          step :issue_store_credit
          step :draw_down_gift_card
          step :create_payment
          step :recalculate_order
          run_hooks :after_apply
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

      # Runs before the balance is read, so the released amount is available
      # to this order. Releasing is all or nothing with the apply itself: a
      # refused release fails the whole workflow, which rolls back the ones
      # that did succeed. Emptying one shopper's cart and then not spending
      # the balance would be the worst of both outcomes.
      #
      # Holds are locked in id order, and the card's own lock is taken first,
      # so two applies of the SAME card serialize and cannot deadlock. Two
      # applies of DIFFERENT cards can still cross when each target already
      # holds the other's card; the database aborts one and the API layer
      # turns that into a retryable conflict (Spree::Api::V3::OrderLock).
      # Releasing outside the target's lock would remove the crossing but
      # give up the all-or-nothing rollback above, which matters more.
      def release_open_holds
        @released_holds = []

        gift_card.open_holds(except: order).each do |hold|
          result = Spree.gift_card_remove_workflow.call(order: hold)

          if result.success?
            @released_holds << hold
          else
            report_unreleased_hold(hold, result)
            failure(order, :gift_card_held_by_another_order)
          end
        end

        gift_card.reload
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
        return if amount.positive? || order.total.zero?

        # Distinguish a spent card from one whose balance is briefly locked
        # up elsewhere — the customer can retry the second, not the first.
        failure(order, :gift_card_held_by_another_order) if held_elsewhere?
        failure(order, :gift_card_no_amount_remaining)
      end

      def held_elsewhere?
        gift_card.holds_being_completed(except: order).any?
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
