require 'spec_helper'

describe "checkout with unshippable items" do
  let!(:stock_location) { create(:stock_location) }
  let(:order) { OrderWalkthrough.up_to(:address) }

  before do
    OrderWalkthrough.add_line_item!(order)
    line_item = order.line_items.last
    stock_item = stock_location.stock_item(line_item.variant)
    stock_item.adjust_count_on_hand -999
    stock_item.backorderable = false
    stock_item.save!

    user = create(:user)
    order.user = user
    order.update!

    Spree::CheckoutController.any_instance.stub(:current_order => order)
    Spree::CheckoutController.any_instance.stub(:try_spree_current_user => user)
    Spree::CheckoutController.any_instance.stub(:skip_state_validation? => true)
    Spree::CheckoutController.any_instance.stub(:ensure_sufficient_stock_lines => true)
  end

  it 'displays and removes' do
    visit spree.checkout_state_path(:delivery)
    page.should have_content('Unshippable Items')

    click_button "Save and Continue"

    order.reload
    order.line_items.count.should eq 1
  end
end

