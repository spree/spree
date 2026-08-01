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

      # @return [Boolean]
      def guest_checkout_disallowed?
        return false if customer.present?

        resolved_channel = channel || store&.default_channel
        return false unless resolved_channel.respond_to?(:guest_checkout_enabled?)

        !resolved_channel.guest_checkout_enabled?
      end
    end
  end
end
