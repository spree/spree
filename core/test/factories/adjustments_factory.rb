Factory.define(:adjustment) do |record|
  record.amount { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  record.description { Faker::Lorem.sentence }

  # associations:
  #record.association(:order, :factory => :order)
end

Factory.define(:charge, :class => Charge) do |record|
  record.amount { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  record.description { Faker::Lorem.sentence }

  # associations:
  #record.association(:order, :factory => :order)
end

Factory.define(:shipping_charge, :class => ShippingCharge) do |record|
  record.amount { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  record.description { Faker::Lorem.sentence }

  # associations:
  #record.association(:order, :factory => :order)
end

Factory.define(:tax_charge, :class => TaxCharge) do |record|
  record.amount { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  record.description { Faker::Lorem.sentence }

  # associations:
  record.association(:order, :factory => :order)
end

Factory.define(:credit, :class => Credit) do |record|
  record.amount { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  record.description { Faker::Lorem.sentence }

  # associations:
  record.association(:order, :factory => :order)
end
