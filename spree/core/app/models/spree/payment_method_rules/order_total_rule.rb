module Spree
  module PaymentMethodRules
    # Bounds the method by the purchase total, per currency — "installments
    # above 5,000" means a different number in EUR and USD. A currency with no
    # entry is unrestricted on that side; bounds are inclusive.
    class OrderTotalRule < Spree::PaymentMethodRule
      preference :min_totals, :hash, keys: :currency, values: :money, default: {}
      preference :max_totals, :hash, keys: :currency, values: :money, default: {}

      validate :minimum_not_above_maximum
      validate :totals_not_negative

      def eligible?(purchase)
        total = purchase.total.to_d
        minimum = threshold(preferred_min_totals, purchase.currency)
        maximum = threshold(preferred_max_totals, purchase.currency)

        (minimum.nil? || total >= minimum) && (maximum.nil? || total <= maximum)
      end

      private

      # A minimum above the maximum in one currency hides the method from every
      # cart in it, which is never what was meant.
      def minimum_not_above_maximum
        (preferred_min_totals || {}).each_key do |currency|
          minimum = threshold(preferred_min_totals, currency)
          maximum = threshold(preferred_max_totals, currency)
          next if minimum.nil? || maximum.nil? || minimum <= maximum

          errors.add(:base, :min_total_above_max,
                     message: I18n.t('spree.errors.messages.min_total_above_max', currency: currency.to_s.upcase))
        end
      end

      # A negative maximum matches no cart, and a negative minimum limits nothing.
      def totals_not_negative
        [preferred_min_totals, preferred_max_totals].each do |amounts|
          (amounts || {}).each_key do |currency|
            value = threshold(amounts, currency)
            next if value.nil? || value >= 0

            errors.add(:base, :negative_total,
                       message: I18n.t('spree.errors.messages.negative_total', currency: currency.to_s.upcase))
          end
        end
      end

      def threshold(amounts, currency)
        value = (amounts || {}).find { |key, _| key.to_s.casecmp?(currency.to_s) }&.last
        BigDecimal(value.to_s) if value.present?
      end
    end
  end
end
