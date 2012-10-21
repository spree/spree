require 'spec_helper'

describe "Address" do
  let!(:canada) { create(:country, :name => "Canada",:states_required => true) }
  let!(:france) { create(:country, :name => "France",:states_required => false) }
  let!(:italy) { create(:country, :name => "Italy",:states_required => true) }

  before(:all) do
    Factory(:state, :name => "Ontario", :country => canada)
  end

  before do
    Spree::Product.delete_all
    @product = create(:product, :name => "RoR Mug", :on_hand => 1)
    @product.save

    @order = create(:order_with_totals, :state => 'cart')
    @order.stub(:available_payment_methods => [create(:bogus_payment_method, :environment => 'test') ])

    visit spree.root_path
    click_link "RoR Mug"
    click_button "add-to-cart-button"
    Spree::Order.last.update_column(:email, "funk@groove.com")
    click_button "Checkout"

    address = "order_bill_address_attributes"
    @country_css = "#{address}_country_id"
    @state_select_css = "##{address}_state_id"
    @state_name_css = "##{address}_state_name"
  end

  it "shows the state collection selection for a country having states", :js => true do
    select canada.name, :from => @country_css
    page.find(@state_select_css).should be_visible
    page.find(@state_name_css).should_not be_visible
  end

  it "shows the state input field for a country with states required but for which states are not defined", :js => true do
    select italy.name, :from => @country_css
    page.find(@state_select_css).should_not be_visible
    page.find(@state_name_css).should be_visible
    page.should_not have_selector("input#{@state_name_css}[disabled]")
  end

  it "shows a disabled state input field for a country where states are not required", :js => true do
     select france.name, :from => @country_css
     page.find(@state_select_css).should_not be_visible
     page.find(@state_name_css).should be_visible
     page.should have_selector("input#{@state_name_css}[disabled]")
  end

  it "should clear the state name when selecting a country without states required", :js =>true do
    select italy.name, :from => @country_css
    page.find(@state_name_css).set("Toscana")

    select france.name, :from => @country_css
    page.find(@state_name_css).should have_content('')
  end
end