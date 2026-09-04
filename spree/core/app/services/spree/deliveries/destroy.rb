module Spree
  module Deliveries
    # Removes a hand-entered consignment that never went anywhere.
    #
    # Two things are not removable. A delivery minted by a label is the
    # label's own record of what was bought, so the way out is refunding it,
    # which drops the delivery when the parcel never moved. And a delivery
    # that arrived is a fact about what happened — its arrival is what the
    # returns window and the withdrawal period count from — so it stays, and
    # a mistake is corrected by fixing the row rather than erasing it.
    class Destroy
      prepend Spree::ServiceModule::Base

      # @param delivery [Spree::Delivery]
      # @return [Spree::ServiceModule::Result]
      def call(delivery:)
        if delivery.shipping_label_id.present?
          delivery.errors.add(:base, Spree.t('deliveries.errors.has_label'))
          return failure(delivery)
        end

        if delivery.delivered?
          delivery.errors.add(:base, Spree.t('deliveries.errors.delivered'))
          return failure(delivery)
        end

        delivery.destroy ? success(delivery) : failure(delivery)
      end
    end
  end
end
