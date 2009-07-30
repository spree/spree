Factory.define(:line_item) do |record|
  record.quantity { rand(777) }
  record.price { BigDecimal.new("#{rand(200)}.#{rand(99)}") }

  # associations: 
  record.association(:order, :factory => :order)
  record.association(:variant, :factory => :variant)
end