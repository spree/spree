module Spree
  module Adjustable
    module Adjuster
      class Promotion < Spree::Adjustable::Adjuster::Base
        def update
          promo_adjustments = adjustments.competing_promos.reload.map { |a| a.update!(adjustable) }
          promos_total = promo_adjustments.compact.sum
          choose_best_promo_adjustment unless promos_total == 0
          promo_total = best_promo_adjustment.try(:amount).to_f if best_promo_adjustment.try(:promotion?)

          update_totals(promo_total)
        end

        private

        # Picks one (and only one) competing discount to be eligible for
        # this order. This adjustment provides the most discount, and if
        # two adjustments have the same amount, then it will pick the
        # latest one.
        def choose_best_promo_adjustment
          if best_promo_adjustment
            other_promotions = adjustments.competing_promos.where.not(id: best_promo_adjustment.id)
            other_promotions.update_all(eligible: false)
          end
        end

        def best_promo_adjustment
          @best_promo_adjustment ||= begin
            adjustments.competing_promos.eligible.reorder('amount ASC, created_at DESC, id DESC').first
          end
        end

        def update_totals(promo_total)
          promo_total ||= 0.0
          @totals[:promo_total] = promo_total
          @totals[:taxable_adjustment_total] += promo_total
        end
      end
    end
  end
end
