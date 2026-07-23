module Spree
  module Adjusters
    # Maintains the distributed discount lines of whole-order promotions
    # (order_level? actions) during recalculation. Their discount exists as
    # one share per line item and must win or lose as a group, so this
    # adjuster works order-wide: it refreshes every action's shares from ONE
    # distributed_amounts batch per action, drops ineligible or zeroed
    # groups, and keeps only the best group (largest total discount, ties to
    # the newest lines). It never creates rows and never touches manual or
    # item-level lines.
    #
    # Must run before Adjusters::Promotion within the :discount pass — the
    # item-level clamp reads the surviving order-level lines.
    class OrderLevelPromotion < Base
      self.type = :discount

      def self.adjust_all(order, adjustables)
        lines_by_action = adjustables
                          .flat_map { |adjustable| adjustable.discount_lines.select(&:promotion?) }
                          .select { |line| line.promotion_action.order_level? }
                          .group_by(&:promotion_action)

        surviving = lines_by_action.filter_map do |action, lines|
          unless action.promotion&.eligible?(order)
            lines.each(&:destroy!)
            next
          end

          shares = action.distributed_amounts(order)
          lines.each do |line|
            amount = shares.fetch(line.line_item_id, 0)

            if amount >= 0
              line.destroy!
            elsif line.amount != amount
              line.update!(amount: amount)
            end
          end

          remaining = lines.reject(&:destroyed?)
          [action, remaining] if remaining.any?
        end

        return if surviving.size <= 1

        best_action, = surviving.min_by do |_action, lines|
          [lines.sum(&:amount), -lines.map(&:created_at).max.to_i, -lines.map(&:id).max]
        end

        surviving.each do |action, lines|
          lines.each(&:destroy!) unless action == best_action
        end
      end
    end
  end
end
