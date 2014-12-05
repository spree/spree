module Spree
  module Adjustable
    class PromotionSelector

      def self.select!(adjustable)
        new(adjustable).select!
      end

      def initialize(adjustable)
        @adjustable = adjustable
      end

      def select!
        find_best_promotion
        find_other_adjustables_to_update
        update_other_adjustables_promo_totals
        make_all_promotion_adjustments_ineligible
        set_only_best_promotions_adjustments_eligible
        adjustable_promo_total
      end

    private
      attr_reader :adjustable
      delegate :promotion_accumulator, :order, to: :adjustable
      delegate :adjustments, :promotions, 
               :promotions_adjustments, :promo_total, to: :promotion_accumulator

      def find_best_promotion
        eligible_promotions = promotions.select{ |p| p.eligible?(adjustable) }
        _, @best_promotion = eligible_promotions.map{ |p| [promo_total(p.id), p] }.min
      end

      def find_other_adjustables_to_update
        @other_adjustables_to_update = adjustments_to_update.map{ |a| [a.adjustable_type, a.adjustable_id] }
        @other_adjustables_to_update.delete(adjustables_type_and_id.values)
      end

      def adjustments_to_update
        adjustments.select{ |a| needs_updating?(a) }
      end

      def needs_updating?(adjustment)
        adjustment.eligible != best_promotions_adjustments.include?(adjustment)
      end

      def best_promotions_adjustments
        @best_promotions_adjustments ||= promotions_adjustments(@best_promotion.try(:id))
      end

      def adjustables_type_and_id
        {adjustable_type: adjustable.class.to_s, adjustable_id: adjustable.id}
      end

      def update_other_adjustables_promo_totals
        @other_adjustables_to_update.each do |(type, id)|
          next if type == 'Spree::Order'
          update_adjustable_promo_total(type, id)
        end
      end

      def update_adjustable_promo_total(type, id)
        adjustments = where(best_promotions_adjustments, adjustable_type: type, adjustable_id: id)
        promo_total = adjustments.sum(&:amount)
        type.constantize.where(id: id).update_all(promo_total: promo_total)
      end

      def where(array, opts={})
        array.select { |a| opts.all?{ |k,v| a.respond_to?(k) && a.send(k) == v } }
      end

      def make_all_promotion_adjustments_ineligible
        order.all_adjustments.promotion.update_all(eligible: false)
      end

      def set_only_best_promotions_adjustments_eligible
        Spree::Adjustment.where(id: best_promotions_adjustments.map(&:id)).update_all(eligible: true)
      end

      def adjustable_promo_total
        where(best_promotions_adjustments, adjustables_type_and_id).sum(&:amount)
      end

    end
  end
end