module Spree
  module Deliveries
    # Records what the carrier says about one consignment in flight.
    #
    # This is the carrier axis: it never moves the owner backwards and never
    # contradicts the merchant. A parcel that bounces or is damaged shows up
    # here as `return_to_sender` or `failure` while the fulfillment still
    # says `fulfilled` — the merchant did hand it over. The one status that
    # crosses over is `delivered`: when every delivery of a fulfillment has
    # arrived, the fulfillment is marked delivered through
    # Spree::Fulfillments::MarkDelivered. A Return owner never transitions —
    # goods arriving is not goods inspected, and Spree::Returns::Receive stays
    # a staff act; anything that wants to react hangs on
    # +after_update_tracking+.
    #
    # Providers call this from their webhook handlers, so it accepts the
    # already-normalized vocabulary rather than any carrier's raw payload:
    # translating a provider's status names is the provider gem's job.
    class UpdateTracking < Spree::Workflow
      hooks :validate, :after_update_tracking

      # @param delivery [Spree::Delivery] the consignment being tracked
      # @param tracking_status [String, nil] one of {Spree::Delivery::STATUSES}
      # @param estimated_delivery_at [Time, nil] carrier's current estimate
      # @param delivered_at [Time, nil] when the carrier says it arrived; used
      #   only when +tracking_status+ is `delivered`, defaulting to now
      # @param details [Hash, nil] provider payload worth keeping — scan events,
      #   the signature, the failure reason
      # @param notify_customer [Boolean] passed through to MarkDelivered when
      #   this update completes the fulfillment's delivery
      # @return [Spree::ServiceModule::Result] the updated delivery on success
      def perform(delivery:, tracking_status: nil, estimated_delivery_at: nil, delivered_at: nil,
                  details: nil, notify_customer: true)
        super

        run_hooks :validate

        step :ensure_known_status
        step :apply_carrier_report
        step :roll_up_owner_delivery

        run_hooks :after_update_tracking
        success(delivery.reload)
      end

      private

      def ensure_known_status
        return if tracking_status.blank?
        return if Spree::Delivery::STATUSES.include?(tracking_status.to_s)

        failure(delivery, Spree.t('fulfillments.errors.unknown_tracking_status', status: tracking_status))
      end

      # Overwrite rather than accumulate: this axis answers "where is it now",
      # and carriers resend the whole picture on every update. Only attributes
      # the caller actually supplied are touched, so a webhook carrying just a
      # scan does not wipe an estimate from an earlier one.
      def apply_carrier_report
        attributes = {}
        attributes[:status] = tracking_status.to_s if tracking_status.present?
        attributes[:estimated_delivery_at] = estimated_delivery_at unless estimated_delivery_at.nil?
        attributes[:details] = details unless details.nil?
        attributes[:delivered_at] = delivered_at || delivery.delivered_at || Time.current if reported_delivered?

        return if attributes.empty?

        # update_columns, deliberately: carrier scans arrive many times per
        # parcel, and a lifecycle event per scan would run the full order
        # status rollup for writes that cannot change any status. The
        # after_update_tracking hook and the fulfillment.delivered event are
        # the notification surface for this axis.
        delivery.update_columns(attributes.merge(updated_at: Time.current))
      end

      # Delivery is the one carrier report that is also a merchant fact, so it
      # crosses over to the fulfillment's status — once every consignment has
      # arrived, and only from `fulfilled`, which MarkDelivered enforces. A
      # carrier reporting delivery on a canceled parcel is noise on this axis.
      def roll_up_owner_delivery
        return unless reported_delivered?

        owner = delivery.owner
        return unless owner.is_a?(Spree::Fulfillment)
        return unless owner.can_mark_delivered?

        # update_columns above left any loaded association holding the old
        # status, and this decides whether the parcel is done.
        owner.deliveries.reset
        return if owner.deliveries.undelivered.exists?

        result = Spree.fulfillment_mark_delivered_workflow.call(
          fulfillment: owner,
          delivered_at: owner.deliveries.maximum(:delivered_at),
          notify_customer: notify_customer
        )

        failure(delivery, result.error.to_s) if result.failure?
      end

      def reported_delivered?
        tracking_status.to_s == 'delivered'
      end
    end
  end
end
