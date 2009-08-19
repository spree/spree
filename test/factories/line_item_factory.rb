Factory.define(:line_item) do |record|
  record.quantity { 1 + rand(10) }
  record.price { BigDecimal.new("#{rand(200)}.#{rand(99)}") }

  # associations: 
  record.association(:order, :factory => :order)
  record.association(:variant, :factory => :variant)
end
