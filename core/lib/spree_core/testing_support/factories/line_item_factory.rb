Factory.define(:line_item) do |record|
  record.quantity 1
  record.price { BigDecimal.new("10.00") }

  # associations:
  record.association(:order, :factory => :order)
  record.association(:variant, :factory => :variant)
end
