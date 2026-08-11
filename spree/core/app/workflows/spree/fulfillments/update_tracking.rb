module Spree
  module Fulfillments
    # Records what the carrier says about a parcel in flight.
    #
    # This is the second axis: it never moves the fulfillment backwards and
    # never contradicts the merchant. A parcel that bounces or is damaged shows
    # up here as `return_to_sender` or `failure` while `status` still says
    # `fulfilled` — the merchant did hand it over, and that fact does not
    # change because the carrier had a bad day. The one status it does write is
    # `delivered`, by delegating to {MarkDelivered}.
    #
    # Providers call this from their webhook handlers, so it accepts the
    # already-normalized vocabulary rather than any carrier's raw payload:
    # translating a provider's status names is the provider gem's job.
    class UpdateTracking < Spree::Workflow
      hooks :validate, :after_update_tracking

      # @param fulfillment [Spree::Fulfillment] the fulfillment being tracked
      # @param tracking_status [String, nil] one of
      #   {Spree::Fulfillment::TRACKING_STATUSES}
      # @param estimated_delivery_at [Time, nil] carrier's current estimate
      # @param delivered_at [Time, nil] when the carrier says it arrived; used
      #   only when +tracking_status+ is `delivered`
      # @param details [Hash, nil] provider payload worth keeping — scan events,
      #   the signature, the failure reason
      # @param notify_customer [Boolean] passed through to {MarkDelivered} when
      #   this update completes the delivery
      # @return [Spree::ServiceModule::Result] the updated fulfillment on success
      def perform(fulfillment:, tracking_status: nil, estimated_delivery_at: nil, delivered_at: nil,
                  details: nil, notify_customer: true)
        super

        run_hooks :validate

        step :ensure_known_status
        step :apply_carrier_report
        step :confirm_delivery_if_reported

        run_hooks :after_update_tracking
        success(fulfillment.reload)
      end

      private

      def ensure_known_status
        return if tracking_status.blank?
        return if Spree::Fulfillment::TRACKING_STATUSES.include?(tracking_status.to_s)

        failure(fulfillment, Spree.t('fulfillments.errors.unknown_tracking_status', status: tracking_status))
      end

      # Overwrite rather than accumulate: this axis answers "where is it now",
      # and carriers resend the whole picture on every update. Only attributes
      # the caller actually supplied are touched, so a webhook carrying just a
      # scan does not wipe an estimate from an earlier one.
      def apply_carrier_report
        attributes = {}
        attributes[:tracking_status] = tracking_status.to_s if tracking_status.present?
        attributes[:estimated_delivery_at] = estimated_delivery_at unless estimated_delivery_at.nil?
        attributes[:tracking_details] = details unless details.nil?

        return if attributes.empty?

        # update_columns, deliberately: carrier scans arrive many times per
        # parcel, and a lifecycle event per scan would run the full order
        # status rollup (via Spree::OrderStatusSubscriber) for writes that
        # cannot change any status. The after_update_tracking hook and the
        # fulfillment.delivered event are the notification surface for this
        # axis. Values are already validated by ensure_known_status.
        fulfillment.update_columns(attributes.merge(updated_at: Time.current))
      end

      # Delivery is the one carrier report that is also a merchant fact, so it
      # crosses over to the status axis — but only from `fulfilled`, and
      # MarkDelivered enforces that. A carrier reporting delivery on a canceled
      # parcel is noise on the tracking axis, not a lifecycle event.
      def confirm_delivery_if_reported
        return unless tracking_status.to_s == 'delivered'
        return unless fulfillment.can_mark_delivered?

        result = Spree.fulfillment_mark_delivered_workflow.call(
          fulfillment: fulfillment,
          delivered_at: delivered_at,
          notify_customer: notify_customer
        )

        failure(fulfillment, result.error.to_s) if result.failure?
      end
    end
  end
end
