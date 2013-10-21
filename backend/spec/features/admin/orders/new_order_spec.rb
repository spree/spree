require 'spec_helper'

describe "New Order" do
  let!(:stock_location) { create(:stock_location_with_items) }
  let!(:product) { create(:product) }
  let!(:state) { create(:state) }
  let!(:user) { create(:user, :email => "foo@bar.com") }
  let!(:payment_method) { create(:payment_method) }
  let!(:shipping_method) { create(:shipping_method) }
  let!(:stock_item) { product.master.stock_items.first.adjust_count_on_hand(10) }

  stub_authorization!

  before do
    visit spree.admin_path
    click_on "Orders"
    click_on "New Order"
  end

  it "completes new order succesfully", js: true do
    select2_search product.name, :from => Spree.t(:name_or_sku)
    click_icon :plus
    click_on "Customer Details"

    within "#select-customer" do
      targetted_select2_search user.email, :from => "#s2id_customer_search"
    end

    check "order_use_billing"
    fill_in_address
    click_on "Update"

    click_on "Payments"
    click_on "Update"

    expect(current_path).to eql(spree.edit_admin_order_path(Spree::Order.last))

    click_on "Payments"
    click_icon "capture"

    click_on "Order Details"
    click_on "ship"
    wait_for_ajax

    page.should have_content("shipped")
  end

  # Regression test for #3336
  it "transitions order after products are selected", js: true do
    click_on "Customer Details"

    targetted_select2_search "foo@bar", :from => "#s2id_customer_search"
    check "order_use_billing"
    fill_in_address
    click_on "Update"

    click_on "Order Details"
    select2_search product.name, :from => Spree.t(:name_or_sku)
    click_icon :plus
    wait_for_ajax
    within(".additional-info .state") do
      page.should have_content("PAYMENT")
    end
  end

  def fill_in_address(kind = "bill")
    fill_in "First Name",              :with => "John 99"
    fill_in "Last Name",               :with => "Doe"
    fill_in "Street Address",          :with => "100 first lane"
    fill_in "Street Address (cont'd)", :with => "#101"
    fill_in "City",                    :with => "Bethesda"
    fill_in "Zip",                     :with => "20170"
    targetted_select2_search state.name, :from => "#s2id_order_#{kind}_address_attributes_state_id"
    fill_in "Phone",                   :with => "123-456-7890"
  end
end
