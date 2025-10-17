module Spree
  module Admin
    module OrdersHelper
      TaxLine = Struct.new(:label, :display_amount, :item, :for_shipment, keyword_init: true) do
        def name
          item_name = item.name
          item_name += " #{Spree.t(:shipment).downcase}" if for_shipment

          "#{label} (#{item_name})"
        end
      end

      def order_summary_tax_lines_additional(order)
        line_item_taxes = order.line_item_adjustments.tax.map { |tax_adjustment| map_to_tax_line(tax_adjustment) }
        shipment_taxes = order.shipment_adjustments.tax.map { |tax_adjustment| map_to_tax_line(tax_adjustment, for_shipment: true) }

        line_item_taxes + shipment_taxes
      end

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
        {
          'A' => 'Street address matches, but 5-digit and 9-digit postal code do not match.',
          'B' => 'Street address matches, but postal code not verified.',
          'C' => 'Street address and postal code do not match.',
          'D' => 'Street address and postal code match. ',
          'E' => 'AVS data is invalid or AVS is not allowed for this card type.',
          'F' => "Card member's name does not match, but billing postal code matches.",
          'G' => 'Non-U.S. issuing bank does not support AVS.',
          'H' => "Card member's name does not match. Street address and postal code match.",
          'I' => 'Address not verified.',
          'J' => "Card member's name, billing address, and postal code match.",
          'K' => "Card member's name matches but billing address and billing postal code do not match.",
          'L' => "Card member's name and billing postal code match, but billing address does not match.",
          'M' => 'Street address and postal code match. ',
          'N' => 'Street address and postal code do not match.',
          'O' => "Card member's name and billing address match, but billing postal code does not match.",
          'P' => 'Postal code matches, but street address not verified.',
          'Q' => "Card member's name, billing address, and postal code match.",
          'R' => 'System unavailable.',
          'S' => 'Bank does not support AVS.',
          'T' => "Card member's name does not match, but street address matches.",
          'U' => 'Address information unavailable. Returned if the U.S. bank does not support non-U.S. AVS or if the AVS in a U.S. bank is not functioning properly.',
          'V' => "Card member's name, billing address, and billing postal code match.",
          'W' => 'Street address does not match, but 9-digit postal code matches.',
          'X' => 'Street address and 9-digit postal code match.',
          'Y' => 'Street address and 5-digit postal code match.',
          'Z' => 'Street address does not match, but 5-digit postal code matches.'
        }
      end

      def cvv_response_code
        {
          'M' => 'CVV2 Match',
          'N' => 'CVV2 No Match',
          'P' => 'Not Processed',
          'S' => 'Issuer indicates that CVV2 data should be present on the card, but the merchant has indicated data is not present on the card',
          'U' => 'Issuer has not certified for CVV2 or Issuer has not provided Visa with the CVV2 encryption keys',
          '' => 'Transaction failed because wrong CVV2 number was entered or no CVV2 number was entered'
        }
      end

      def order_filter_dropdown_value
        if params.dig(:q, :shipment_state_not_in) == ['shipped', 'canceled']
          Spree.t('admin.orders.unfulfilled')
        elsif params.dig(:q, :shipment_state_eq) == 'shipped'
          Spree.t('admin.orders.fulfilled')
        elsif params.dig(:q, :state_in) == ['canceled','partially_canceled']
          Spree.t('admin.orders.canceled')
        elsif params.dig(:q, :refunded)&.present?
          Spree.t('admin.orders.refunded')
        elsif params.dig(:q, :partially_refunded)&.present?
          Spree.t('admin.orders.partially_refunded')
        else
          Spree.t('admin.orders.all_orders')
        end
      end

      private

      def map_to_tax_line(tax_adjustment, for_shipment: false)
        TaxLine.new(
          label: tax_adjustment.label,
          display_amount: tax_adjustment.display_amount,
          item: tax_adjustment.adjustable,
          for_shipment: for_shipment
        )
      end
    end
  end
end
