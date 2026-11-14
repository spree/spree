module CartLimits
  # Caps every cart line at MAX units of one variant. Registered on both cart
  # workflows: carts.add_item adds to a line's quantity, carts.upsert_items
  # sets it, so the quantity each one is checked against differs.
  class MaxQuantityPerLine
    MAX = 10

    def call(workflow)
      return if resulting_quantity(workflow) <= MAX

      workflow.errors.add(:quantity, :purchase_limit_exceeded,
                          message: "You can order at most #{MAX} of this item.")
      workflow.reject!
    end

    private

    def resulting_quantity(workflow)
      workflow.quantity.to_i
    end
  end
end
