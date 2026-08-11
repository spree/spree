module SpreeEasyPost
  # Receives EasyPost's `tracker.updated` webhooks and hands them to
  # {Spree::Fulfillments::UpdateTracking}.
  #
  # Always answers 200 once the payload has been read. A webhook endpoint that
  # returns an error gets retried, and there is nothing to retry for a tracker
  # we do not recognise — the parcel may belong to another system entirely.
  # Genuine failures are reported rather than escalated to the carrier.
  class WebhooksController < ActionController::Base
    protect_from_forgery with: :null_session
    skip_forgery_protection

    def create
      event = SpreeEasyPost::TrackerEvent.from_webhook(params)
      return head(:ok) if event.nil?

      fulfillment = find_fulfillment(event.tracking_code)
      return head(:ok) if fulfillment.nil?

      Spree.fulfillment_update_tracking_workflow.call(
        fulfillment: fulfillment,
        tracking_status: event.status,
        estimated_delivery_at: event.estimated_delivery_at,
        delivered_at: event.delivered_at,
        details: event.details
      )

      head :ok
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { tracking_code: params.dig(:result, :tracking_code) })
      head :ok
    end

    private

    # Matched on tracking code alone: EasyPost's webhook says nothing about
    # which store a parcel belongs to, and a tracking code is unique in
    # practice. Scoped to fulfillments that actually shipped so a recycled code
    # cannot reopen an old parcel's tracking.
    def find_fulfillment(tracking_code)
      Spree::Fulfillment.where(tracking: tracking_code).where.not(status: 'canceled').reverse_chronological.first
    end
  end
end
