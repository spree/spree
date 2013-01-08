module PromotionCreation
  def create_per_product_promotion product_name, discount_amount, event = "Add to cart"

    visit spree.admin_path
    click_link "Promotions"
    click_link "New Promotion"

    promotion_name = "Bundle d#{discount_amount}"
    fill_in "Name", :with => promotion_name
    select2 event, :from => "Event Name"
    click_button "Create"
    page.should have_content("Editing Promotion")

    select2 "Product(s)", :from => "Add rule of type"
    within("#rule_fields") { click_button "Add" }
    select2_search product_name, :from => "Choose products", :dropdown_css => ".product_picker"
    within('#rule_fields') { click_button "Update" }

    select2 "Create adjustment", :from => "Add action of type"
    within('#action_fields') { click_button "Add" }
    select2 "Flat Rate (per item)", :from => "Calculator"
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
    select2 "Coupon code added", :from => "Event Name"
    fill_in "Code", :with => coupon_code
    click_button "Create"
    page.should have_content("Editing Promotion")

    select2 "Item total", :from => "Add rule of type"
    within('#rule_fields') { click_button "Add" }

    eventually_fill_in "promotion_promotion_rules_attributes_#{Spree::Promotion.count}_preferred_amount", :with => order_min
    within('#rule_fields') { click_button "Update" }

    select2 "Create adjustment", :from => "Add action of type"
    within('#action_fields') { click_button "Add" }
    select2 "Flat Rate (per order)", :from => "Calculator"
    within('#actions_container') { click_button "Update" }

    within('.calculator-fields') { fill_in "Amount", :with => order_discount }
    within('#actions_container') { click_button "Update" }

    Spree::Promotion.find_by_name promotion_name
  end

  def create_basic_coupon_promotion(code)
    promo = Spree::Promotion.create!({
      :name => "A promotion",
      :event_name => "spree.checkout.coupon_code_added",
      :code => code,
      # So that we don't get caught out by the feature where a promotion
      # cannot be applied to an order when an order is older than the promotion
      :created_at => 1.day.ago,
      :starts_at => 1.day.ago,
    }, :without_protection => true)
    action = Spree::Promotion::Actions::CreateAdjustment.new
    action.promotion = promo
    action.calculator = create(:calculator)
    action.save!
    promo.actions.reload # this makes the actions available
    promo
  end

end


RSpec.configure do |c|
  c.include PromotionCreation
end
