require 'spec_helper'

describe 'Shipping methods', :js => true do
  let!(:product) { create(:product) }
  let!(:country) { create(:country) }
  let!(:state) { create(:state, :country => country) }
  let!(:zone) { create(:global_zone) }
  let!(:address) { create(:address, :state => state, :country => country) }
  let!(:shipping_category) { create(:shipping_category, :name => "Default") }
  let!(:shipping_method) { create(:shipping_method, :zone => zone, :shipping_category => shipping_category) }
  let!(:payment_method) { create(:payment_method) }

  def walk_through_checkout_to_delivery
    visit spree.root_path
    click_link product.name
    click_button "Add To Cart"
    click_button "Checkout"

    fill_in "Customer E-Mail", :with => "customer@example.com"
    str_addr = "bill_address"
    select address.country.name, :from => "order_#{str_addr}_attributes_country_id"
    ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
      fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
    end
    select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
    click_button "Save and Continue"
  end

  def assert_shipping_method_visible
    page.should have_content("Shipping Method")
    within("#shipping_method") do
      page.should have_content(shipping_method.name),
        "Shipping method #{shipping_method.name.inspect} not found on page."
    end
  end

  def refute_shipping_method_visible
    page.should have_content("No shipping methods available for selected location")
  end

  context "when rule is no products match" do
    before do
      shipping_method.update_column(:match_none, true)
    end

    context "when rule is satisfied" do
      it "can see the shipping method" do
        walk_through_checkout_to_delivery
        assert_shipping_method_visible
      end
    end

    context "when rule is not satisfied" do
      before do
        product.update_column(:shipping_category_id, shipping_category.id)
      end

      it "cannot see the shipping method" do
        walk_through_checkout_to_delivery
        refute_shipping_method_visible
      end
    end
  end

  context "when the rule is all products match" do
    before do
      shipping_method.update_column(:match_all, true)
    end

    context "when rule is satisfied" do
      before do
        product.update_column(:shipping_category_id, shipping_category.id)
      end

      it "can see the shipping method" do
        walk_through_checkout_to_delivery
        assert_shipping_method_visible
      end
    end

    context "when the rule is not satisfied" do
      it "cannot see the shipping method" do
        walk_through_checkout_to_delivery
        refute_shipping_method_visible
      end
    end
  end

  context "when the rule is one product matches" do
    before do
      shipping_method.update_column(:match_one, true)
    end

    context "when rule is satisfied" do
      before do
        product.update_column(:shipping_category_id, shipping_category.id)
      end

      it "can see the shipping method" do
        walk_through_checkout_to_delivery
        assert_shipping_method_visible
      end
    end

    context "when the rule is not satisfied" do
      it "cannot see the shipping method" do
        walk_through_checkout_to_delivery
        refute_shipping_method_visible
      end
    end
  end
end
