module Spree
  module Adjusters
    # Maintains item-level promotion-backed DiscountLines during
    # recalculation: refreshes amounts, deletes lines that zero out or lose
    # eligibility, and enforces best-promo competition per adjustable. It
    # never creates rows — activation (PromotionAction#perform) does — and
    # never touches manual lines or the distributed lines of whole-order
    # promotions (those belong to Adjusters::OrderLevelPromotion, which runs
    # first).
    class Promotion < Base
      self.type = :discount

      def update
        # Candidates were created by PromotionAction#perform at activation
        # time — recalculation refreshes them, it never creates rows. The
        # association is preloaded by the OrderUpdater; filter in Ruby, don't
        # re-query.
        candidates = adjustable.discount_lines.select do |line|
          line.promotion? && !line.destroyed? && !line.promotion_action.order_level?
        end

        # Recompute each candidate: refresh its amount, or destroy it when it
        # zeroes out or loses eligibility (strictly-negative invariant —
        # zeroed rows are deleted, not kept).
        candidates.each do |line|
          amount = line.promotion_action.compute_amount(adjustable)

          if amount >= 0 || !line.promotion&.eligible?(adjustable)
            line.destroy!
          elsif line.amount != amount
            line.update!(amount: amount)
          end
        end

        candidates = candidates.reject(&:destroyed?)

        # Best promo wins per adjustable: most negative amount, ties broken by newest
        best = candidates.min_by { |line| [line.amount, -line.created_at.to_i, -line.id] }
        return unless best

        (candidates - [best]).each(&:destroy!)
      end
    end
  end
end
