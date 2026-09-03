module Spree
  module Deliveries
    # Removes a hand-entered consignment. A delivery minted by a label is not
    # removable on its own — the label is the record of what was bought, so
    # the way out is refunding it, which removes the delivery when the parcel
    # never moved.
    class Destroy
      prepend Spree::ServiceModule::Base

      # @param delivery [Spree::Delivery]
      # @return [Spree::ServiceModule::Result]
      def call(delivery:)
        if delivery.shipping_label_id.present?
          delivery.errors.add(:base, Spree.t('deliveries.errors.has_label'))
          return failure(delivery)
        end

        delivery.destroy ? success(delivery) : failure(delivery)
      end
    end
  end
end
