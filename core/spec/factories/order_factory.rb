Factory.define(:order) do |record|
  # associations:
  record.association(:user, :factory => :user)
  record.association(:bill_address, :factory => :address)
  record.completed_at nil
end

Factory.define :order_with_totals, :parent => :order do |f|
  f.after_create { |order| Factory(:line_item, :order => order) }
end
