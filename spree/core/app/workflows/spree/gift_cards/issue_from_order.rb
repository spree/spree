module Spree
  module GiftCards
    # Issues the gift cards a paid order bought: one per unit of every gift
    # card line, worth the denomination's price.
    #
    # Only once the order is paid in full, never on an unpaid placement, so a
    # code is only ever spendable for money the store has received. Two events
    # can bring the order here: `order.placed`, for a payment taken while the
    # buyer was still in checkout (which announces no `order.paid` of its
    # own), and `order.paid`, for a payment taken later. Either may arrive
    # first or more than once, so the run is idempotent: under the order's
    # lock, a line that already has its cards issues nothing, and a canceled
    # order issues nothing.
    #
    # The card is a bearer instrument — no customer is attached. It goes to
    # the line's recipient, or to the order's email when the buyer named no
    # one; the `gift_card.issued` event is what sends it.
    class IssueFromOrder < Spree::Workflow
      hooks :after_issue

      # Cards created by this run — hook handlers read them.
      attr_reader :gift_cards

      # @param order [Spree::Order]
      # @param paid [Boolean] true when the caller already knows the order is
      #   paid in full (an `order.paid` event), which is the only answer for a
      #   marketplace order whose payments belong to its group
      # @return [Spree::ServiceModule::Result] value is the cards issued by
      #   this run, empty when there was nothing to issue
      def perform(order:, paid: false)
        super

        @gift_cards = []
        # Most orders buy no gift card, and both events reach every order.
        halt!([]) unless order.completed? && gift_card_lines.exists?
        halt!([]) unless paid || order.payment_status == 'paid' || order.settled_in_full?

        ApplicationRecord.transaction do
          order.lock!
          step :issue_gift_cards
          run_hooks :after_issue
        end

        gift_cards.each { |gift_card| gift_card.publish_event('gift_card.issued') }
        success(gift_cards)
      end

      private

      # Checked again under the lock, which reloaded the row: a cancellation
      # committed after the first look must not be followed by cards.
      def issue_gift_cards
        return if order.canceled?

        gift_card_lines.includes(:gift_cards, :gift_card_recipient).each do |line_item|
          # A card staff gave away at no charge has no value to issue.
          next unless line_item.price.positive?

          expires_at = expiry_date(line_item)
          (line_item.quantity - line_item.gift_cards.size).times do
            @gift_cards << line_item.gift_cards.create!(
              store: order.store,
              amount: line_item.price,
              currency: order.currency,
              expires_at: expires_at
            )
          end
        end
      end

      def gift_card_lines
        order.line_items.joins(variant: :product).where(Spree::Product.table_name => { gift_card: true })
      end

      # Counted from the day the recipient receives the card, so a card
      # scheduled weeks ahead does not arrive with its validity spent.
      def expiry_date(line_item)
        days = order.store.preferred_gift_card_default_validity_days
        return if days.blank?

        zone = Time.find_zone(order.store.preferred_timezone) || Time.zone
        send_on = line_item.gift_card_recipient&.send_at&.in_time_zone(zone)&.to_date
        [zone.today, send_on].compact.max + days.days
      end
    end
  end
end
