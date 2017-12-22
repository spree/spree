require_dependency 'spree/calculator'

module Spree
  class Calculator::NForX < Calculator
    preference :number, :integer, default: 0
    preference :amount, :decimal, default: 0

    def self.description
      Spree.t(:n_for_x)
    end

    def compute(object=nil)
      return 0 if object.nil? || group_count(object) == 0

      discount = applicable_variants(object).map(&:price).sum - (self.preferred_amount * group_count)

      return 0 if discount < 0

      discount
    end

    private

      def applicable_variants(object = nil)
        return @applicable_variants if !@applicable_variants.nil?

        @applicable_variants = []

        matching_line_items(object).each do |l|
          break if @applicable_variants.size == group_count(object) * self.preferred_number

          l.quantity.times do
            @applicable_variants << l.variant

            break if @applicable_variants.size == group_count * self.preferred_number
          end
        end

        @applicable_variants
      end

      def group_count(object = nil)
        @group_count ||= matching_line_items(object).map(&:quantity).sum / self.preferred_number
      end

      def matching_line_items(object = nil)
        @matching_line_items ||= object.line_items.select { |l| matching_variants.include?(l.variant) }.sort_by! { |l| l.variant.price }
      end

      def matching_variants
        @matching_variants ||= if compute_on_promotion?
          self.calculable.promotion.rules.select { |r| r.respond_to?(:variants) }.map(&:variants).flatten
        end
      end

      def compute_on_promotion?
        return true
        @compute_on_promotion ||= self.calculable.respond_to?(:promotion)
      end

  end
end