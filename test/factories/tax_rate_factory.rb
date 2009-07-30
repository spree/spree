Factory.define(:tax_rate) do |f|
  f.amount 0.10
  f.tax_category {|r| r.association(:tax_category)}
end