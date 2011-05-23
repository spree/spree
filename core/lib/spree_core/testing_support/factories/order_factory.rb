Factory.define(:order) do |record|
  # associations:
  record.association(:user, :factory => :user)
  record.association(:bill_address, :factory => :address)
  record.completed_at nil
  record.bill_address_id nil
  record.ship_address_id nil
end

Factory.define :order_with_totals, :parent => :order do |f|
  f.after_create { |order| Factory(:line_item, :order => order) }
end

Factory.define :order_with_inventory_unit_shipped, :parent => :order do |f|
  f.after_create do |order|
    Factory(:inventory_unit, :order => order, :state => 'shipped')
  end
end
