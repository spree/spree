module Spree
  class FinalizeOrder
    attr_reader :order

    def initialize(order)
      @order = order
    end

    ##
    # Finalize an in-progress order's adjustments, and shipments 
    # after the payment has been processed and checkout is complete.
    def execute!
      lock_adjustments
      updater.update_payment_state

      order.shipments.each do |s| 
        s.update!(order)
        FinalizeShipment.new(s).execute!
      end

      updater.update_shipment_state
      order.save!
      updater.run_hooks

      order.touch :completed_at

      order.deliver_order_confirmation_email unless order.confirmation_delivered?

      order.consider_risk
    end

    private

    def lock_adjustments
      order.all_adjustments.each{|a| a.close}
    end

    def updater
      OrderUpdater.new(order)
    end

  end
end
