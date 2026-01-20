module Spree
  module Admin
    class OrderSummaryPresenter
      SPREE_ADJUSTMENT_SOURCE_TYPES = ['Spree::PromotionAction', 'Spree::TaxRate'].freeze

      attr_reader :order

      def initialize(order)
        @order = order
      end

      def rows
        [
          *metadata_rows,
          :separator,
          currency_row,
          subtotal_row,
          shipping_row,
          promo_row,
          manual_adjustments_row,
          *custom_adjustment_rows,
          included_tax_row,
          additional_tax_row,
          total_row,
          :separator,
          payment_total_row,
          outstanding_balance_row
        ].compact
      end

      def metadata_rows
        rows = []

        if order.created_by.present?
          rows << {
            label: Spree.t(:created_by),
            value: order.created_by.name,
            link: Spree::Core::Engine.routes.url_helpers.admin_admin_user_path(order.created_by)
          }
        end

        rows << {
          label: Spree.t(:created_at),
          value: order.created_at,
          type: :datetime
        }

        if order.completed_at.present?
          rows << {
            label: I18n.t('activerecord.attributes.spree/order.completed_at'),
            value: order.completed_at,
            type: :datetime
          }
        end

        if order.canceled? && order.canceled_at.present?
          rows << {
            label: Spree.t(:canceled_at),
            value: order.canceled_at,
            type: :datetime
          }

          if order.canceler.present?
            rows << {
              label: Spree.t(:canceler),
              value: order.canceler.name
            }
          end
        end

        rows
      end

      def currency_row
        {
          label: Spree.t(:currency),
          value: order.currency,
          id: 'currency',
          type: :code
        }
      end

      def subtotal_row
        {
          label: Spree.t(:subtotal),
          value: order.display_item_total,
          id: 'item_total'
        }
      end

      def shipping_row
        return nil unless order.checkout_steps.include?('delivery') && order.ship_total > 0

        {
          label: Spree.t(:ship_total),
          value: order.display_ship_total,
          id: 'ship_total'
        }
      end

      def promo_row
        return nil if order.promo_total.zero?

        {
          label: Spree.t(:discount_amount),
          value: order.display_promo_total,
          id: 'promo_total'
        }
      end

      def manual_adjustments_row
        manual_adjustments = order.all_adjustments.eligible.where(source_type: nil)
        total = manual_adjustments.sum(:amount)
        return nil if total.zero?

        {
          label: Spree.t(:manual_adjustments),
          value: Spree::Money.new(total, currency: order.currency),
          id: 'manual_adjustments_total'
        }
      end

      def custom_adjustment_rows
        custom_adjustments = order.all_adjustments.eligible.where.not(source_type: [nil, *SPREE_ADJUSTMENT_SOURCE_TYPES])

        custom_adjustments.group_by(&:source_type).map do |source_type, adjustments|
          total = adjustments.sum(&:amount)
          next nil if total.zero?

          {
            label: translate_source_type(source_type),
            value: Spree::Money.new(total, currency: order.currency),
            id: source_type.demodulize.underscore
          }
        end.compact
      end

      def included_tax_row
        {
          label: Spree.t(:tax_included),
          value: order.display_included_tax_total,
          id: 'included_tax_total'
        }
      end

      def additional_tax_row
        {
          label: Spree.t(:tax),
          value: order.display_additional_tax_total,
          id: 'additional_tax_total'
        }
      end

      def total_row
        {
          label: Spree.t(:total),
          value: order.display_total,
          id: 'order_total',
          bold: true
        }
      end

      def payment_total_row
        {
          label: Spree.t(:payment_total),
          value: order.display_payment_total,
          id: 'payment_total',
          highlight: true
        }
      end

      def outstanding_balance_row
        {
          label: Spree.t(:outstanding_balance),
          value: order.display_outstanding_balance,
          id: 'outstanding_balance',
          highlight: true,
          danger: order.outstanding_balance > 0
        }
      end

      private

      def translate_source_type(source_type)
        key = source_type.demodulize.underscore
        Spree.t(key, default: key.humanize)
      end
    end
  end
end
