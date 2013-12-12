require 'spec_helper'

# Tests for #3958's features
describe "Order Line Items", js: true do
  stub_authorization!
  
  before do
    # Removing the delivery step causes the order page to render a different
    # partial, called _line_items, which shows line items rather than shipments
    Spree::Order.stub :checkout_step_names => [:address, :payment, :confirm, :complete]
  end

  let!(:order) do
    order = create(:order_with_line_items, :line_items_count => 1)
    order.shipments.destroy_all
    order
  end

  it "can edit a line item's quantity" do
    visit spree.edit_admin_order_path(order)
    within(".line-items") do
      within_row(1) do
        find(".edit-line-item").click
        fill_in "quantity", :with => 10
        find(".save-line-item").click
        page.should have_content("10", :css => ".line-item-qty-show")
        page.should have_content("$100.00", :css => ".line-item-total")
      end
    end
  end

  it "can delete a line item" do
    visit spree.edit_admin_order_path(order)

    product_name = find(".line-items tr:nth-child(1) .line-item-name").text

    within(".line-items") do
      within_row(1) do
        find(".delete-line-item").click
        page.driver.browser.switch_to.alert.accept
      end
    end

    page.should_not have_content(product_name)
  end
end