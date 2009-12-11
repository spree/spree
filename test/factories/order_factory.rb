Factory.define(:order) do |record|
  # associations:
  record.association(:user, :factory => :user)
end

Factory.define :order_with_totals, :parent => :order do |f|
  f.line_items { [Factory(:line_item)] }
end