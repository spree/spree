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
    class Apply < Spree::Workflow
      hooks :validate, :after_apply

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

      def ensure_amount_available
        return if amount.positive? || order.total.zero?

        failure(order, :gift_card_no_amount_remaining)
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
