module Spree
  class ShipmentHandler
    include Spree::Shipment::Emails
    include Spree::IntegrationsConcern

    class << self
      def factory(shipment)
        # Do we have a specialized shipping-method-specific handler? e.g:
        # Given shipment.shipping_method = Spree::ShippingMethod::DigitalDownload
        # do we have Spree::ShipmentHandler::DigitalDownload?
        if sm_handler = "Spree::ShipmentHandler::#{shipment.shipping_method.name.split('::').last}".safe_constantize
          sm_handler.new(shipment)
        else
          new(shipment)
        end
      end
    end

    def initialize(shipment)
      @shipment = shipment
    end

    def perform
      @shipment.inventory_units.each &:ship!
      @shipment.process_order_payments if Spree::Config[:auto_capture_on_dispatch]
      @shipment.touch :shipped_at
      update_order_shipment_state
      send_shipped_email
    end

    protected

    def update_order_shipment_state
      order = @shipment.order

      new_state = OrderUpdater.new(order).update_shipment_state
      order.update_columns(shipment_state: new_state, updated_at: Time.current)
    end
  end
end
