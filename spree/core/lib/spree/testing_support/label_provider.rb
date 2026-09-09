module Spree
  module TestingSupport
    # A fulfillment provider that "buys" labels without a carrier, for specs
    # exercising the label workflows and the surfaces built on them.
    class LabelProvider < Spree::FulfillmentProvider::Base
      def self.generates_labels?
        true
      end

      # Class-level so specs can swap the purchase or make it fail.
      class << self
        attr_accessor :purchase_result, :refund_result

        def reset!
          self.purchase_result = nil
          self.refund_result = 'refunded'
        end
      end
      reset!

      def purchase_label(owner)
        self.class.purchase_result || Spree::LabelPurchase.new(
          external_id: "shp_#{owner.id}",
          carrier: 'ups',
          service: 'Ground',
          tracking_number: '1Z879E930346834440',
          tracking_url: 'https://tracker.example/1Z879E930346834440',
          cost: 7.25,
          currency: 'USD',
          format: 'pdf',
          file_url: 'https://carrier.example/label.pdf',
          metadata: { 'tracker_id' => 'trk_1' }
        )
      end

      def refund_label(_shipping_label)
        self.class.refund_result
      end

      def create_fulfillment(_fulfillment)
        {}
      end

      def cancel_fulfillment(_fulfillment)
        true
      end
    end
  end
end
