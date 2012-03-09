FactoryGirl.define do
  factory :order, :class => Spree::Order do
    # associations:
    association(:user, :factory => :user)
    association(:bill_address, :factory => :address)
    completed_at nil
    bill_address_id nil
    ship_address_id nil
    email 'foo@example.com'
  end

  factory :order_with_totals, :parent => :order do
    after_create { |order| Factory(:line_item, :order => order) }
  end

  factory :order_with_inventory_unit_shipped, :parent => :order do
    after_create do |order|
      Factory(:line_item, :order => order)
      Factory(:inventory_unit, :order => order, :state => 'shipped')
    end
  end

  factory :completed_order_with_totals, :parent => :order_with_totals do
    bill_address { Factory(:address) }
    ship_address { Factory(:address) }
    after_create do |order|
      Factory(:inventory_unit, :order => order, :state => 'shipped')
    end
    state 'complete'
    completed_at Time.now
  end

  factory :complete_order, :parent => :order_with_totals do
    state "confirm"
    association(:bill_address, :factory => :address)
    association(:ship_address, :factory => :address)
    association(:shipping_method, :factory => :shipping_method)
    after_create do |order|
      order.next!
    end
  end
end
