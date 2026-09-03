module Spree
  module Fulfillments
    # @deprecated Tracking is a Spree::Delivery since 6.0 — use
    #   Spree::Deliveries::UpdateTracking with +delivery:+. This shell resolves
    #   the fulfillment's primary delivery for one release; removed in 6.1.
    class UpdateTracking < Spree::Workflow
      hooks :validate, :after_update_tracking

      # @param fulfillment [Spree::Fulfillment]
      # @return [Spree::ServiceModule::Result] the fulfillment on success
      def perform(fulfillment:, **arguments)
        super(fulfillment: fulfillment)

        Spree::Deprecation.warn(
          'Spree::Fulfillments::UpdateTracking is deprecated and will be removed in Spree 6.1. ' \
          'Use Spree::Deliveries::UpdateTracking with delivery: instead.'
        )

        delivery = fulfillment.primary_delivery
        failure(fulfillment, Spree.t('deliveries.errors.not_found')) if delivery.nil?

        result = Spree.delivery_update_tracking_workflow.call(delivery: delivery, **arguments)
        failure(fulfillment, result.error.to_s) if result.failure?

        success(fulfillment.reload)
      end
    end
  end
end
