module PromotionCreation
  def create_per_product_promotion product_name, discount_amount, event = "Add to cart"
    promotion_name = "Bundle d#{discount_amount}"

    visit spree.admin_path
    click_link "Promotions"
    click_link "New Promotion"

    fill_in "Name", :with => promotion_name
    select event, :from => "Event"
    click_button "Create"
    page.should have_content("Editing Promotion")

    # add product_name to last promotion
    promotion = Spree::Promotion.last
    promotion.rules << Spree::Promotion::Rules::Product.new()
    product = Spree::Product.find_by_name(product_name)
    rule = promotion.rules.last
    rule.products << product
    if rule.save
      puts "Created promotion: new price for #{product_name} is #{product.price - discount_amount} (was #{product.price})"
    else
      puts "Failed to create promotion: price for #{product_name} is still #{product.price}"
    end

    select "Create adjustment", :from => "Add action of type"
    within('#action_fields') { click_button "Add" }
    select "Flat Rate (per item)", :from => "Calculator"
    within('#actions_container') { click_button "Update" }
    within('.calculator-fields') { fill_in "Amount", :with => discount_amount.to_s }
    within('#actions_container') { click_button "Update" }

    Spree::Promotion.find_by_name promotion_name
  end

  def create_per_order_coupon_promotion order_min, order_discount, coupon_code
    visit spree.admin_path
    click_link "Promotions"
    click_link "New Promotion"

    promotion_name = "Order's total > $#{order_min}, Discount #{order_discount}"
    fill_in "Name", :with => promotion_name
    fill_in "Usage Limit", :with => "100"
    select "Coupon code added", :from => "Event"
    fill_in "Code", :with => coupon_code
    click_button "Create"
    page.should have_content("Editing Promotion")

    select "Item total", :from => "Add rule of type"
    within('#rule_fields') { click_button "Add" }

    eventually_fill_in "promotion_promotion_rules_attributes_#{Spree::Promotion.count}_preferred_amount", :with => order_min
    within('#rule_fields') { click_button "Update" }

    select "Create adjustment", :from => "Add action of type"
    within('#action_fields') { click_button "Add" }
    select "Flat Rate (per order)", :from => "Calculator"
    within('#actions_container') { click_button "Update" }

    within('.calculator-fields') { fill_in "Amount", :with => order_discount }
    within('#actions_container') { click_button "Update" }

    Spree::Promotion.find_by_name promotion_name
  end
end


RSpec.configure do |c|
  c.include PromotionCreation
end
