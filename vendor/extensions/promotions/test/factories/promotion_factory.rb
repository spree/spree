Factory.define :promotion do |f|
  f.code nil
  f.combine true
  f.calculator {|r| Factory(:calculator, :calculable => r.instance_eval{@instance}) }
end

Factory.define :promotion_rule do |r|
  r.association(:promotion, :factory => :promotion)
end

Factory.define(:promotion_credit, :class => PromotionCredit) do |f|
  f.amount { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  f.description { Faker::Lorem.sentence }

  # associations:
  f.association(:order, :factory => :order)
  f.association(:adjustment_source, :factory => :promotion)
end
