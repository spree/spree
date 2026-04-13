module Spree
  module Checkout
    class Advance
      prepend Spree::ServiceModule::Base

      def call(order:, state: nil, shipping_method_id: nil)
        return failure(order) if state.present? && !order.has_checkout_step?(state)
        return success(order) if state.present? && order.passed_checkout_step?(state)

        old_state = order.state
        order_updater_ran = false

        # We need to check how many times we transitioned between checkout steps and return the error if no transition has been made
        # We'll always return an error when passing the `state` arg and not reaching the targeted state
        transitions_count = 0

        until cannot_make_transition?(order, state)
          next_result = Spree.checkout_next_service.call(order: order)
          return failure(order, order.errors) if next_result.failure? && (transitions_count.zero? || state.present?)

          transitions_count +=1

          # Quick Checkout with Google Pay not always sends events for shipping method selection
          # we have to check this after payment

          if order.delivery? &&
              shipping_method_id.present? &&
              order.shipments.count == 1 &&
              order.shipping_method.id != shipping_method_id

            shipment = order.shipments.valid.first
            if shipment
              rate = shipment.shipping_rates.find_by(shipping_method_id: shipping_method_id)
              if rate
                shipment.selected_shipping_rate_id = rate.id
                order.update_with_updater!
                order_updater_ran = true
              end
            end
          end
        end

        if order.state != old_state && !order_updater_ran
          order.updater.update_shipment_state
          order.updater.update_payment_state
          order.save! if order.changed?
        end

        success(order)
      end

      private

      def cannot_make_transition?(order, state = nil)
        order.state == state || order.confirm? || order.complete? || order.errors.present? || order.passed_checkout_step?(state)
      end

      def report_advance_error(error, order)
        # You can report checkout advance error here
      end
    end
  end
end
