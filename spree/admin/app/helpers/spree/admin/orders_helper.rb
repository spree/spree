module Spree
  module Admin
    module OrdersHelper
      def order_payment_state(order, options = {})
        return if order.payment_state.blank?

        badge_class = if order.order_refunded?
                        'badge-danger'
                      elsif order.partially_refunded?
                        'badge-warning'
                      else
                        "badge-#{order.payment_state}"
                      end

        content_tag :span, class: "badge #{options[:class]} #{badge_class}" do
          if order.order_refunded?
            icon('credit-card-refund') + Spree.t('payment_states.refunded')
          elsif order.partially_refunded?
            icon('credit-card-refund') + Spree.t('payment_states.partially_refunded')
          elsif order.payment_state == 'failed'
            icon('cancel') + Spree.t('payment_states.failed')
          elsif order.payment_state == 'void'
            icon('cancel') + Spree.t('payment_states.void')
          elsif order.payment_state == 'paid'
            icon('check') + Spree.t('payment_states.paid')
          else
            icon('progress') + Spree.t("payment_states.#{order.payment_state}")
          end
        end
      end

      def order_shipment_state(order, options = {})
        shipment_state(order.shipment_state, options)
      end

      def shipment_state(shipment_state, options = {})
        return if shipment_state.blank?

        content_tag :span, class: "badge  #{options[:class]} badge-#{shipment_state}" do
          if shipment_state == 'shipped'
            icon('check') + Spree.t('shipment_states.shipped')
          elsif shipment_state == 'partial'
            icon('progress-check') + Spree.t('shipment_states.partial')
          elsif shipment_state == 'canceled'
            icon('cancel') + Spree.t('shipment_states.canceled')
          else
            icon('progress') + Spree.t("shipment_states.#{shipment_state}")
          end
        end
      end

      def payment_state_badge(state)
        content_tag :span, class: "badge badge-#{state}" do
          if state == 'completed'
            icon('check') + Spree.t('payment_states.completed')
          elsif state == 'failed'
            icon('cancel') + Spree.t('payment_states.failed')
          elsif state == 'processing'
            icon('progress') + Spree.t('payment_states.processing')
          else
            Spree.t("payment_states.#{state}")
          end
        end
      end

      def line_item_shipment_price(line_item, quantity)
        Spree::Money.new(line_item.price * quantity, currency: line_item.currency)
      end

      def ready_to_ship_orders_count
        @ready_to_ship_orders_count ||= begin
          if defined?(current_vendor)
            if current_vendor.present?
              current_vendor.orders.complete.ready_to_ship.count
            else
              current_store.orders.without_vendor.complete.ready_to_ship.count
            end
          else
            current_store.orders.complete.ready_to_ship.count
          end
        end
      end

      def avs_response_code
        ('A'..'Z').each_with_object({}) do |code, codes|
          codes[code] = Spree.t("admin.orders.avs_responses.#{code.downcase}")
        end
      end

      def cvv_response_code
        {
          'M' => Spree.t('admin.orders.cvv_responses.m'),
          'N' => Spree.t('admin.orders.cvv_responses.n'),
          'P' => Spree.t('admin.orders.cvv_responses.p'),
          'S' => Spree.t('admin.orders.cvv_responses.s'),
          'U' => Spree.t('admin.orders.cvv_responses.u'),
          '' => Spree.t('admin.orders.cvv_responses.blank')
        }
      end
    end
  end
end
