module CartLimits
  # carts.add_item hands the handler the increment, not the line's new total.
  class MaxQuantityPerLineOnAdd < MaxQuantityPerLine
    private

    def resulting_quantity(workflow)
      already = workflow.cart.line_items.where(variant_id: workflow.variant.id).sum(:quantity)
      already + (workflow.quantity.presence || 1).to_i
    end
  end
end
