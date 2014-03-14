require 'spec_helper'

describe "Address", inaccessible: true do
  let!(:product) { create(:product, :name => "RoR Mug") }
  let!(:order) { create(:order_with_totals, :state => 'cart') }

  stub_authorization!

  after do
    Capybara.ignore_hidden_elements = true
  end

  before do
    Capybara.ignore_hidden_elements = false

    visit spree.root_path

    click_link "RoR Mug"
    click_button "add-to-cart-button"

    address = "order_bill_address_attributes"
    @country_css = "#{address}_country_code"
    @region_css = "##{address}_region_code"
  end

  context "country has subregions", :js => true, :focus => true do
    before { Spree::Config[:default_country_code] = 'UK' }

    it "shows the state collection selection" do
      click_button "Checkout"

      select canada.name, :from => @country_css
      page.should have_selector(@region_css, visible: true)
      find(@region_css)['class'].should =~ /required/
    end
  end
end
