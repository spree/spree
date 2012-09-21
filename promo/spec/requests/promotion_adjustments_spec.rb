require 'spec_helper'

describe "Promotion Adjustments" do
  stub_authorization!

  context "coupon promotions", :js => true do
    before(:each) do
      # creates a default shipping method which is required for checkout
      create(:bogus_payment_method, :environment => 'test')
      # creates a check payment method so we don't need to worry about cc details
      create(:payment_method)

      sm = create(:shipping_method, :zone => Spree::Zone.find_by_name('North America'))
      sm.calculator.set_preference(:amount, 10)

      user = create(:admin_user)
      create(:product, :name => "RoR Mug", :price => "40")
      create(:product, :name => "RoR Bag", :price => "20")

      visit spree.admin_path
      click_link "Promotions"
      click_link "New Promotion"
    end

    let!(:address) { create(:address, :state => Spree::State.first) }

    it "should properly populate Spree::Product#possible_promotions" do
      promotion = create_per_product_promotion 'RoR Mug', 5.0
      promotion.update_column :advertise, true

      mug = Spree::Product.find_by_name 'RoR Mug'
      bag = Spree::Product.find_by_name 'RoR Bag'

      mug.possible_promotions.size.should == 1
      bag.possible_promotions.size.should == 0

      # expire the promotion
      promotion.expires_at = Date.today.beginning_of_week
      promotion.starts_at = Date.today.beginning_of_week.advance(:day => 3)
      promotion.save!

      mug.possible_promotions.size.should == 0
    end

    it "should allow an admin to create a flat rate discount coupon promo" do
      fill_in "Name", :with => "Order's total > $30"
      fill_in "Usage Limit", :with => "100"
      select "Coupon code added", :from => "Event"
      fill_in "Code", :with => "ORDER_38"
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      fill_in "Order total meets these criteria", :with => "30"
      within('#rule_fields') { click_button "Update" }

      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Rate (per order)", :from => "Calculator"
      within('#actions_container') { click_button "Update" }

      within('.calculator-fields') { fill_in "Amount", :with => "5" }
      within('#actions_container') { click_button "Update" }

      visit spree.root_path
      click_link "RoR Mug"
      click_button "Add To Cart"
      click_button "Checkout"

      fill_in "Customer E-Mail", :with => "spree@example.com"
      str_addr = "bill_address"
      select "United States", :from => "order_#{str_addr}_attributes_country_id"
      ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
        fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
      end
      select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
      check "order_use_billing"
      click_button "Save and Continue"
      click_button "Save and Continue"

      choose('Credit Card')
      fill_in "card_number", :with => "4111111111111111"
      fill_in "card_code", :with => "123"

      fill_in "order_coupon_code", :with => "ORDER_38"
      click_button "Save and Continue"

      Spree::Order.last.adjustments.promotion.map(&:amount).sum.should == -5.0
    end

    it "should allow an admin to create a single user coupon promo with flat rate discount" do
      fill_in "Name", :with => "Order's total > $30"
      fill_in "Usage Limit", :with => "1"
      select "Coupon code added", :from => "Event"
      fill_in "Code", :with => "SINGLE_USE"
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      fill_in "Order total meets these criteria", :with => "30"
      within('#rule_fields') { click_button "Update" }

      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Rate (per order)", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('#action_fields') { fill_in "Amount", :with => "5" }
      within('#actions_container') { click_button "Update" }

      visit spree.root_path
      click_link "RoR Mug"
      click_button "Add To Cart"
      click_button "Checkout"

      fill_in "Customer E-Mail", :with => "spree@example.com"
      str_addr = "bill_address"
      select "United States", :from => "order_#{str_addr}_attributes_country_id"
      ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
        fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
      end
      select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
      check "order_use_billing"
      click_button "Save and Continue"
      click_button "Save and Continue"
      fill_in "order_coupon_code", :with => "SINGLE_USE"

      choose('Credit Card')
      fill_in "card_number", :with => "4111111111111111"
      fill_in "card_code", :with => "123"
      click_button "Save and Continue"

      Spree::Order.first.total.to_f.should == 45.00

      click_button "Place Order"

      visit spree.root_path
      click_link "RoR Mug"
      click_button "Add To Cart"
      click_button "Checkout"

      fill_in "Customer E-Mail", :with => "spree@example.com"
      str_addr = "bill_address"
      select "United States", :from => "order_#{str_addr}_attributes_country_id"
      ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
        fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
      end
      select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
      check "order_use_billing"
      click_button "Save and Continue"
      click_button "Save and Continue"

      choose('Credit Card')
      fill_in "card_number", :with => "4111111111111111"
      fill_in "card_code", :with => "123"
      fill_in "order_coupon_code", :with => "SINGLE_USE"
      click_button "Save and Continue"

      Spree::Order.last.total.to_f.should == 50.00
    end

    it "should allow an admin to create an automatic promo with flat percent discount" do
      fill_in "Name", :with => "Order's total > $30"
      select "Order contents changed", :from => "Event"
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      fill_in "Order total meets these criteria", :with => "30"
      within('#rule_fields') { click_button "Update" }

      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Percent", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Flat Percent", :with => "10" }
      within('#actions_container') { click_button "Update" }

      visit spree.root_path
      click_link "RoR Mug"
      click_button "Add To Cart"
      Spree::Order.last.total.to_f.should == 36.00
      visit spree.root_path
      click_link "RoR Bag"
      click_button "Add To Cart"
      Spree::Order.last.total.to_f.should == 54.00
    end

    it "should allow an admin to create an automatic promotion with free shipping (no code)" do
      fill_in "Name", :with => "Free Shipping"
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      fill_in "Order total meets these criteria", :with => "30"
      within('#rule_fields') { click_button "Update" }

      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Free Shipping", :from => "Calculator"
      within('#actions_container') { click_button "Update" }

      visit spree.root_path
      click_link "RoR Bag"
      click_button "Add To Cart"
      click_button "Checkout"

      fill_in "Customer E-Mail", :with => "spree@example.com"
      str_addr = "bill_address"
      select "United States", :from => "order_#{str_addr}_attributes_country_id"
      ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
        fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
      end
      select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
      check "order_use_billing"
      click_button "Save and Continue"
      click_button "Save and Continue"

      choose('Credit Card')
      fill_in "card_number", :with => "4111111111111111"
      fill_in "card_code", :with => "123"
      click_button "Save and Continue"
      Spree::Order.last.total.to_f.should == 30.00 # bag(20) + shipping(10)
      page.should_not have_content("Free Shipping")

      visit spree.root_path
      click_link "RoR Mug"
      click_button "Add To Cart"
      click_button "Checkout"

      str_addr = "bill_address"
      select "United States", :from => "order_#{str_addr}_attributes_country_id"
      ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
        fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
      end
      select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
      check "order_use_billing"
      click_button "Save and Continue"
      click_button "Save and Continue"
      choose('Credit Card')
      fill_in "card_number", :with => "4111111111111111"
      fill_in "card_code", :with => "123"

      click_button "Save and Continue"
      Spree::Order.last.total.to_f.should == 60.00 # bag(20) + mug(40) + free shipping(0)
      page.should have_content("Free Shipping")
    end

    it "should allow an admin to create an automatic promo requiring a landing page to be visited" do
      fill_in "Name", :with => "Deal"
      select "Visit static content page", :from => "Event"
      fill_in "Path", :with => "content/cvv"
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Rate (per order)", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Amount", :with => "4" }
      within('#actions_container') { click_button "Update" }

      visit spree.root_path
      click_link "RoR Mug"
      click_button "Add To Cart"
      Spree::Order.last.total.to_f.should == 40.00

      visit "/content/cvv"
      visit spree.root_path
      click_link "RoR Mug"
      click_button "Add To Cart"
      Spree::Order.last.total.to_f.should == 76.00
    end

    it "should not update promotional adjustments after the order is complete" do
      promo = create_per_product_promotion "RoR Mug", 10.0, "Order contents changed"

      add_to_cart 'RoR Mug'
      o = Spree::Order.last
      o.finalize!

      o.completed?.should be_true
      o.total.to_f.should == 30.00
      o.adjustments.eligible.promotion.size.should == 1

      # change promotion amount and update order
      promo.actions.first.calculator.preferred_amount = 20.00
      o.update!

      o.adjustments.eligible.promotion.first.amount.to_f.should == -10.00
      o.reload.total.to_f.should == 30.00
    end

    it "should update promotional adjustment when promotion expiration date changes" do
      # TODO if the event subscription changes to add to cart, this test will break
      promo = create_per_product_promotion "RoR Mug", 10.0, "Order contents changed"

      add_to_cart 'RoR Mug'
      Spree::Order.last.total.to_f.should == 30.0

      # push the expiration back
      promo.expires_at = Date.today.beginning_of_week
      promo.starts_at = Date.today.beginning_of_week.advance(:day => 3)
      promo.save!

      click_button 'Update'
      Spree::Order.last.total.to_f.should == 40.0
      Spree::Order.last.adjustments.promotion.size.should == 0

      promo.starts_at = Date.yesterday.to_time
      promo.expires_at = Date.tomorrow.to_time
      promo.save!

      click_button 'Update'
      Spree::Order.last.total.to_f.should == 30.00
    end

    it "should update the adjustment amount if the promotion changes and the promotion event is refired" do
      promo = create_per_product_promotion 'RoR Mug', 5.0

      add_to_cart 'RoR Mug'
      Spree::Order.last.total.to_f.should == 35.00

      promo.actions.first.calculator.preferred_amount = 10.00

      click_button "Update"
      Spree::Order.last.total.to_f.should == 30.00
    end

    it "should pick the best promotion when two promotions exist for the same product" do
      create_per_product_promotion("RoR Mug", 5.0)
      add_to_cart "RoR Mug"
      Spree::Order.last.total.to_f.should == 35.00

      create_per_product_promotion("RoR Mug", 10.0)
      Spree::Activator.active.event_name_starts_with('spree.cart.add').size.should == 2

      update_first_item_quantity 0
      add_to_cart "RoR Mug"

      Spree::Order.last.total.to_f.should == 30.00
    end

    it "should not lose the coupon promotion if other automatic promotions exist but are of lesser value" do
      create_per_order_coupon_promotion 5, 19, "COUPON"
      create_per_product_promotion "RoR Bag", 10.0, "Order contents changed"
      create_per_product_promotion "RoR Bag", 15.0, "Order contents changed"

      add_to_cart 'RoR Bag'
      Spree::Order.last.reload.total.to_f.should == 5

      fill_coupon 'COUPON'
      Spree::Order.last.reload.total.to_f.should == 1

      # should use the 15 off per product promo (20 - 15) * 2
      update_first_item_quantity 2
      Spree::Order.last.reload.total.to_f.should == 10

      # TODO the promotion system should 'remember' that the user submitted a coupon promotion
      # and fallback to that promotion in this case because it is the better discount

      # update_first_item_quantity 1
      # Spree::Order.last.reload.total.to_f.should == 1
    end

    # Regression test for #1416
    it "should allow an admin to create an automatic promo requiring a specific product to be bought" do
      create_per_product_promotion("RoR Mug", 5.0)
      create_per_product_promotion("RoR Bag", 10.0)

      add_to_cart "RoR Mug"
      add_to_cart "RoR Bag"

      # first promotion should be effective on current order
      first_promotion = Spree::Promotion.first
      first_promotion.actions.first.calculator.compute(Spree::Order.last).should == 5.0

      # second promotion should be effective on current order
      second_promotion = Spree::Promotion.last
      second_promotion.actions.first.calculator.compute(Spree::Order.last).should == 10.0

      do_checkout

      # Mug discount ($5) is not taken into account due to #1526
      # Only "best" discount is taken into account
      Spree::Order.last.total.to_f.should == 60.0 # mug(40) + bag(20) - bag_discount(10) + shipping(10)
    end

    it "should allow an admin to create a promotion that adds a 'free' item to the cart" do
      fill_in "Name", :with => "Bundle"
      select "Coupon code added", :from => "Event"
      fill_in "Code", :with => "5ZHED2DH"
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Create line items", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      fill_in "Name or SKU", :with => "RoR Mug"
      find(:xpath, '//div/h4[contains(.,"RoR Mug")]').click
      within('.add-line-item') { click_button "Add" }

      within('#actions_container') { click_button "Update" }

      select "Create adjustment", :from => "Add action of type"
      within('#new_promotion_action_form') { click_button "Add" }
      select "Flat Rate (per order)", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Amount", :with => "40.00" }
      within('#actions_container') { click_button "Update" }

      visit spree.root_path
      click_link "RoR Bag"
      click_button "Add To Cart"
      click_button "Checkout"

      str_addr = "bill_address"
      fill_in "order_email", :with => "buyer@spreecommerce.com"
      select "United States", :from => "order_#{str_addr}_attributes_country_id"
      ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
        fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
      end
      select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
      check "order_use_billing"
      click_button "Save and Continue"
      click_button "Save and Continue"

      choose('Credit Card')
      fill_in "card_number", :with => "4111111111111111"
      fill_in "card_code", :with => "123"

      fill_in "order_coupon_code", :with => "5ZHED2DH"
      click_button "Save and Continue"

      last_order = Spree::Order.last
      last_order.line_items.count.should == 2
      last_order.line_items.map(&:price).should =~ [20.00, 40.00]
      last_order.item_total.to_f.should == 60.00
      last_order.adjustments.promotion.map(&:amount).sum.to_f.should == -40.00
      last_order.total.to_f.should == 30.00
    end

    it "ceasing to be eligible for a promotion with item total rule then becoming eligible again" do
      fill_in "Name", :with => "Spend over $50 and save $5"
      select "Order contents changed", :from => "Event"
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      fill_in "Order total meets these criteria", :with => "50"
      within('#rule_fields') { click_button "Update" }

      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Rate (per order)", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Amount", :with => "5" }
      within('#actions_container') { click_button "Update" }

      visit spree.root_path
      click_link "RoR Bag"
      click_button "Add To Cart"
      Spree::Order.last.total.to_f.should == 20.00

      fill_in "order[line_items_attributes][0][quantity]", :with => "2"
      click_button "Update"
      Spree::Order.last.total.to_f.should == 40.00
      Spree::Order.last.adjustments.eligible.promotion.count.should == 0

      fill_in "order[line_items_attributes][0][quantity]", :with => "3"
      click_button "Update"
      Spree::Order.last.total.to_f.should == 55.00
      Spree::Order.last.adjustments.eligible.promotion.count.should == 1

      fill_in "order[line_items_attributes][0][quantity]", :with => "2"
      click_button "Update"
      Spree::Order.last.total.to_f.should == 40.00
      Spree::Order.last.adjustments.eligible.promotion.count.should == 0

      fill_in "order[line_items_attributes][0][quantity]", :with => "3"
      click_button "Update"
      Spree::Order.last.total.to_f.should == 55.00
    end

    it "only counting the most valuable promotion adjustment in an order" do
      fill_in "Name", :with => "$5 off"
      select "Order contents changed", :from => "Event"
      click_button "Create"
      page.should have_content("Editing Promotion")
      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Rate (per order)", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Amount", :with => "5" }
      within('#actions_container') { click_button "Update" }

      visit spree.admin_promotions_path
      click_link "New Promotion"
      fill_in "Name", :with => "10% off"
      select "Order contents changed", :from => "Event"
      click_button "Create"
      page.should have_content("Editing Promotion")
      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Percent", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Flat Percent", :with => "10" }
      within('#actions_container') { click_button "Update" }

      visit spree.root_path
      click_link "RoR Bag"
      click_button "Add To Cart"
      Spree::Order.last.total.to_f.should == 15.00

      fill_in "order[line_items_attributes][0][quantity]", :with => "2"
      click_button "Update"
      Spree::Order.last.total.to_f.should == 35.00

      fill_in "order[line_items_attributes][0][quantity]", :with => "3"
      click_button "Update"
      Spree::Order.last.total.to_f.should == 54.00
    end

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
      promotion_name = "Order's total > $#{order_min}, Discount #{order_discount}"

      visit spree.admin_path
      click_link "Promotions"
      click_link "New Promotion"

      fill_in "Name", :with => promotion_name
      fill_in "Usage Limit", :with => "100"
      select "Coupon code added", :from => "Event"
      fill_in "Code", :with => coupon_code
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      fill_in "Order total meets these criteria", :with => order_min
      within('#rule_fields') { click_button "Update" }

      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Rate (per order)", :from => "Calculator"
      within('#actions_container') { click_button "Update" }

      within('.calculator-fields') { fill_in "Amount", :with => order_discount }
      within('#actions_container') { click_button "Update" }

      Spree::Promotion.find_by_name promotion_name
    end

    def fill_coupon coupon
      visit '/cart'
      fill_in 'order_coupon_code', :with => coupon
      click_button 'Update'
    end

    def update_first_item_quantity quantity
      visit '/cart'
      fill_in 'order_line_items_attributes_0_quantity', :with => quantity
      click_button "Update"
    end

    def add_to_cart product_name
      visit spree.root_path
      click_link product_name
      click_button "Add To Cart"
    end

    def do_checkout
      click_button "Checkout"
      str_addr = "bill_address"
      fill_in "order_email", :with => "buyer@spreecommerce.com"
      select "United States", :from => "order_#{str_addr}_attributes_country_id"
      ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
        fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
      end
      select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
      check "order_use_billing"
      click_button "Save and Continue"
      click_button "Save and Continue"
      choose('Credit Card')
      fill_in "card_number", :with => "4111111111111111"
      fill_in "card_code", :with => "123"
      click_button "Save and Continue"
    end
  end
end
