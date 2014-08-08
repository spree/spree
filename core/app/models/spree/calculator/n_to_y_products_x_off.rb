require_dependency 'spree/calculator'

module Spree
  class Calculator::NToYProductsXOff < Calculator
    preference :n_items, :integer, default: 1
    preference :y_items, :integer, default: 2
    preference :percent, :decimal, default: 50.0

    def self.description
      Spree.t(:n_to_y_products_off)
    end

    def compute(object = nil)
      return 0 if object.nil?

      # assumes that the products/variants in the rule are the variants targeted for the promotion

      more_count = 1
      discount = 0

      self.matching_line_items(object).each do |line_item|
        break if more_count > self.preferred_y_items

        line_item.quantity.times do
          break if more_count > self.preferred_y_items

          if more_count > self.preferred_n_items
            discount += line_item.price * self.preferred_percent / 100.0
          end

          more_count += 1
        end
      end

      discount
    end

    protected

      def matching_line_items(object = nil)
        @matching_line_items ||= object.line_items.select { |l| matching_variants.include?(l.variant) }.sort_by! { |l| l.variant.price }
      end

      def matching_variants
        @matching_variants ||= if compute_on_promotion?
          self.calculable.promotion.rules.map do |rule|
            if rule.respond_to?(:products)
              rule.products.map(&:variants_including_master)
            elsif rule.respond_to?(:variants)
              rule.variants
            else
              []
            end
          end.flatten
        end
      end

      # Determines wether or not the calculable object is a promotion
      def compute_on_promotion?
        @compute_on_promotion ||= self.calculable.respond_to?(:promotion)
      end
      
  end
end
