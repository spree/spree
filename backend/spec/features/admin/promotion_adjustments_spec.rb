require 'spec_helper'

describe "Promotion Adjustments", :type => :feature do
  stub_authorization!

  context "coupon promotions", :js => true do
    before(:each) do
      visit spree.admin_path
      click_link "Promotions"
      click_link "New Promotion"
    end

    it "should allow an admin to create a flat rate discount coupon promo" do
      fill_in "Name", :with => "Promotion"
      fill_in "Code", :with => "order"
      click_button "Create"
      expect(page).to have_content("Editing Promotion")

      select2 "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }

      eventually_fill_in "promotion_promotion_rules_attributes_#{Spree::Promotion.count}_preferred_amount_min", :with => 30
      eventually_fill_in "promotion_promotion_rules_attributes_#{Spree::Promotion.count}_preferred_amount_max", :with => 60
      within('#rule_fields') { click_button "Update" }

      select2 "Create whole-order adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select2 "Flat Rate", :from => "Calculator"
      within('#actions_container') { click_button "Update" }

      within('.calculator-fields') { fill_in "Amount", :with => 5 }
      within('#actions_container') { click_button "Update" }

      promotion = Spree::Promotion.find_by_name("Promotion")
      expect(promotion.code).to eq("order")

      first_rule = promotion.rules.first!
      expect(first_rule.class).to eq(Spree::Promotion::Rules::ItemTotal)
      expect(first_rule.preferred_amount_min).to eq(30)
      expect(first_rule.preferred_amount_max).to eq(60)

      first_action = promotion.actions.first!
      expect(first_action.class).to eq(Spree::Promotion::Actions::CreateAdjustment)
      first_action_calculator = first_action.calculator
      expect(first_action_calculator.class).to eq(Spree::Calculator::FlatRate)
      expect(first_action_calculator.preferred_amount).to eq(5)
    end

    it "should allow an admin to create a single user coupon promo with flat rate discount" do
      fill_in "Name", :with => "Promotion"
      fill_in "Usage Limit", :with => "1"
      fill_in "Code", :with => "single_use"
      click_button "Create"
      expect(page).to have_content("Editing Promotion")

      select2 "Create whole-order adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select2 "Flat Rate", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('#action_fields') { fill_in "Amount", :with => "5" }
      within('#actions_container') { click_button "Update" }

      promotion = Spree::Promotion.find_by_name("Promotion")
      expect(promotion.usage_limit).to eq(1)
      expect(promotion.code).to eq("single_use")

      first_action = promotion.actions.first!
      expect(first_action.class).to eq(Spree::Promotion::Actions::CreateAdjustment)
      first_action_calculator = first_action.calculator
      expect(first_action_calculator.class).to eq(Spree::Calculator::FlatRate)
      expect(first_action_calculator.preferred_amount).to eq(5)
    end

    it "should allow an admin to create an automatic promo with flat percent discount" do
      fill_in "Name", :with => "Promotion"
      click_button "Create"
      expect(page).to have_content("Editing Promotion")

      select2 "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }

      eventually_fill_in "promotion_promotion_rules_attributes_1_preferred_amount_min", :with => 30
      eventually_fill_in "promotion_promotion_rules_attributes_1_preferred_amount_max", :with => 60
      within('#rule_fields') { click_button "Update" }

      select2 "Create whole-order adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select2 "Flat Percent", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Flat Percent", :with => "10" }
      within('#actions_container') { click_button "Update" }

      promotion = Spree::Promotion.find_by_name("Promotion")
      expect(promotion.code).to be_blank

      first_rule = promotion.rules.first!
      expect(first_rule.class).to eq(Spree::Promotion::Rules::ItemTotal)
      expect(first_rule.preferred_amount_min).to eq(30)
      expect(first_rule.preferred_amount_max).to eq(60)

      first_action = promotion.actions.first!
      expect(first_action.class).to eq(Spree::Promotion::Actions::CreateAdjustment)
      first_action_calculator = first_action.calculator
      expect(first_action_calculator.class).to eq(Spree::Calculator::FlatPercentItemTotal)
      expect(first_action_calculator.preferred_flat_percent).to eq(10)
    end

    it "should allow an admin to create an product promo with percent per item discount" do
      create(:product, :name => "RoR Mug")

      fill_in "Name", :with => "Promotion"
      click_button "Create"
      expect(page).to have_content("Editing Promotion")

      select2 "Product(s)", :from => "Add rule of type"
      within("#rule_fields") { click_button "Add" }
      select2_search "RoR Mug", :from => "Choose products"
      within('#rule_fields') { click_button "Update" }

      select2 "Create per-line-item adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select2 "Percent Per Item", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Percent", :with => "10" }
      within('#actions_container') { click_button "Update" }

      promotion = Spree::Promotion.find_by_name("Promotion")
      expect(promotion.code).to be_blank

      first_rule = promotion.rules.first!
      expect(first_rule.class).to eq(Spree::Promotion::Rules::Product)
      expect(first_rule.products.map(&:name)).to include("RoR Mug")

      first_action = promotion.actions.first!
      expect(first_action.class).to eq(Spree::Promotion::Actions::CreateItemAdjustments)
      first_action_calculator = first_action.calculator
      expect(first_action_calculator.class).to eq(Spree::Calculator::PercentOnLineItem)
      expect(first_action_calculator.preferred_percent).to eq(10)
    end

    xit "should allow an admin to create an automatic promotion with free shipping (no code)" do
      fill_in "Name", :with => "Promotion"
      click_button "Create"
      expect(page).to have_content("Editing Promotion")

      select2 "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      eventually_fill_in "promotion_promotion_rules_attributes_1_preferred_amount", :with => "30"
      within('#rule_fields') { click_button "Update" }

      select2 "Create whole-order adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select2 "Free Shipping", :from => "Calculator"
      within('#actions_container') { click_button "Update" }

      promotion = Spree::Promotion.find_by_name("Promotion")
      expect(promotion.code).to be_blank

      first_rule = promotion.rules.first!
      expect(first_rule.class).to eq(Spree::Promotion::Rules::ItemTotal)

      first_action = promotion.actions.first!
      expect(first_action.class).to eq(Spree::Promotion::Actions::CreateAdjustment)
      first_action_calculator = first_action.calculator
      expect(first_action_calculator.class).to eq(Spree::Calculator::FreeShipping)
    end

    it "should allow an admin to create an automatic promo requiring a landing page to be visited" do
      fill_in "Name", :with => "Promotion"
      fill_in "Path", :with => "content/cvv"
      click_button "Create"
      expect(page).to have_content("Editing Promotion")

      select2 "Create whole-order adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select2 "Flat Rate", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Amount", :with => "4" }
      within('#actions_container') { click_button "Update" }

      promotion = Spree::Promotion.find_by_name("Promotion")
      expect(promotion.path).to eq("content/cvv")
      expect(promotion.code).to be_blank
      expect(promotion.rules).to be_blank

      first_action = promotion.actions.first!
      expect(first_action.class).to eq(Spree::Promotion::Actions::CreateAdjustment)
      first_action_calculator = first_action.calculator
      expect(first_action_calculator.class).to eq(Spree::Calculator::FlatRate)
      expect(first_action_calculator.preferred_amount).to eq(4)
    end

    it "should allow an admin to create a promotion that adds a 'free' item to the cart" do
      create(:product, :name => "RoR Mug")
      fill_in "Name", :with => "Promotion"
      fill_in "Code", :with => "complex"
      click_button "Create"
      expect(page).to have_content("Editing Promotion")

      select2 "Create line items", :from => "Add action of type"

      within('#action_fields') { click_button "Add" }

      page.find('.create_line_items .select2-choice').click
      page.find('.select2-input').set('RoR Mug')
      page.find('.select2-highlighted').click

      within('#actions_container') { click_button "Update" }

      select2 "Create whole-order adjustment", :from => "Add action of type"
      within('#new_promotion_action_form') { click_button "Add" }
      select2 "Flat Rate", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Amount", :with => "40.00" }
      within('#actions_container') { click_button "Update" }

      promotion = Spree::Promotion.find_by_name("Promotion")
      expect(promotion.code).to eq("complex")

      first_action = promotion.actions.first!
      expect(first_action.class).to eq(Spree::Promotion::Actions::CreateLineItems)
      line_item = expect(first_action.promotion_action_line_items).not_to be_empty
    end

    it "ceasing to be eligible for a promotion with item total rule then becoming eligible again" do
      fill_in "Name", :with => "Promotion"
      click_button "Create"
      expect(page).to have_content("Editing Promotion")

      select2 "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      eventually_fill_in "promotion_promotion_rules_attributes_1_preferred_amount_min", :with => "50"
      eventually_fill_in "promotion_promotion_rules_attributes_1_preferred_amount_max", :with => "150"
      within('#rule_fields') { click_button "Update" }

      select2 "Create whole-order adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select2 "Flat Rate", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Amount", :with => "5" }
      within('#actions_container') { click_button "Update" }

      promotion = Spree::Promotion.find_by_name("Promotion")

      first_rule = promotion.rules.first!
      expect(first_rule.class).to eq(Spree::Promotion::Rules::ItemTotal)
      expect(first_rule.preferred_amount_min).to eq(50)
      expect(first_rule.preferred_amount_max).to eq(150)

      first_action = promotion.actions.first!
      expect(first_action.class).to eq(Spree::Promotion::Actions::CreateAdjustment)
      expect(first_action.calculator.class).to eq(Spree::Calculator::FlatRate)
      expect(first_action.calculator.preferred_amount).to eq(5)
    end
  end
end
