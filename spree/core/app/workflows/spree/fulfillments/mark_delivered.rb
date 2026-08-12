module Spree
  module Fulfillments
    # Records that the customer received the goods — the end of the lifecycle,
    # which used to stop at handover.
    #
    # Three things reach it: a carrier reporting delivery (through
    # {Spree::Fulfillments::UpdateTracking}), a staff member pressing a button
    # because they know the parcel arrived, and — for pickup — the customer
    # collecting it. Merchants without any carrier integration still get a
    # usable delivered state that way.
    #
    # In the workflow tier for its hooks: `delivered` is what return windows,
    # review invitations and the EU withdrawal period count from, so host apps
    # need somewhere to hang that work.
    class MarkDelivered < Spree::Workflow
      hooks :validate, :after_mark_delivered

      # @param fulfillment [Spree::Fulfillment] the fulfillment that arrived
      # @param delivered_at [Time, nil] when it arrived; defaults to now.
      #   Carriers report a delivery timestamp that is usually earlier than the
      #   webhook, and the return window has to run from the real one.
      # @param notify_customer [Boolean] whether subscribers should email the
      #   customer about the delivery
      # @return [Spree::ServiceModule::Result] the delivered fulfillment on success
      def perform(fulfillment:, delivered_at: nil, notify_customer: true)
        super

        # Veto point — a host app that confirms delivery through its own
        # channel can reject a carrier's optimistic report here.
        run_hooks :validate

        step :ensure_deliverable
        step :mark_delivered

        run_hooks :after_mark_delivered
        success(fulfillment.reload)
      end

      private

      def ensure_deliverable
        return if fulfillment.can_mark_delivered?

        failure(fulfillment, Spree.t('fulfillments.errors.cannot_mark_delivered'))
      end

      def mark_delivered
        fulfillment.notify_customer = notify_customer
        fulfillment.update!(status: 'delivered', delivered_at: delivered_at || Time.current)
        fulfillment.publish_fulfillment_delivered_event
        fulfillment.order&.update_statuses!
      end
    end
  end
end
