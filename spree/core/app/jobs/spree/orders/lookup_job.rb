module Spree
  module Orders
    # "Find my order": checks an order number and email together and, on a
    # match, announces it so the order's own address receives a link.
    #
    # Runs in the background for every request, match or not, so the Store
    # API answers both in the same time and the response never reveals
    # whether an email placed an order (docs/plans/6.1-returns-portal.md).
    class LookupJob < Spree::BaseJob
      queue_as Spree.queues.default

      # @param store_id [Integer]
      # @param number [String]
      # @param email [String]
      def perform(store_id, number, email)
        store = Spree::Store.find_by(id: store_id)
        return if store.nil? || number.blank? || email.blank?

        # As typed, or upcased for a hand-typed `r123`: a store may configure
        # a lowercase number prefix, so the stored casing cannot be assumed.
        order = store.orders.complete.find_by(number: [number.strip, number.strip.upcase].uniq)
        return unless order&.email.to_s.casecmp?(email.to_s.strip)

        order.publish_event('order.lookup_requested')
      end
    end
  end
end
