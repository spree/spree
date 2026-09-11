module Spree
  module Purchase
    # Lifecycle predicates shared by Spree::Cart and Spree::Order.
    # Cart-only markers (completing?, readonly completion lock) and
    # order-only ones (placed?, canceled?) stay on their hosts.
    module Lifecycle
      extend ActiveSupport::Concern

      included do
        alias_method :complete?, :completed?
      end

      # @return [Boolean]
      def completed?
        completed_at.present?
      end

      # Checkout begins once any checkout-only data is present (email or a
      # shipping address). Drives stock-reservation dispatch.
      #
      # @return [Boolean]
      def in_checkout?
        !completed? && (email.present? || ship_address_id.present?)
      end

      # A completed record is an immutable audit record, and settled money
      # must never be deleted.
      #
      # @return [Boolean]
      def can_be_deleted?
        !completed? && payments.completed.empty?
      end

      # @return [Boolean]
      def backordered?
        fulfillment_items.any?(&:backordered?)
      end

      # A +prices_hidden+ or +approval_required+ channel also disallows
      # guest completion regardless of the +guest_checkout+ flag — prices
      # are withheld from guests, and a buyer who cannot see prices cannot
      # meaningfully place an order.
      #
      # @return [Boolean]
      def guest_checkout_disallowed?
        return false if customer.present?
        return false if channel.blank?
        return true if channel.storefront_prices_hidden?
        return true if channel.storefront_approval_required?

        !channel.resolved_guest_checkout
      end
    end
  end
end
