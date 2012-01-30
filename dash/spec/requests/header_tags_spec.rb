require 'spec_helper'

describe "Header Tags" do
  before do
    @product = Factory(:product, :name => "RoR Mug")

    Spree::DashConfiguration.new.app_id = 1111
    Spree::DashConfiguration.new.site_id = 2222
    Spree::DashConfiguration.new.token = "test_token"
  end

  it "includes the site_id on the home page" do
    visit spree.root_path
    page.should have_content('jirafe= {"id":"2222"}')
  end

  it "includes the product tag on the product page" do
    visit spree.root_path
    click_link "RoR Mug"
    page.should have_content('"product":{"name":"RoR Mug"')
  end

  it "includes the cart tag on the cart page" do
    visit spree.root_path
    click_link "RoR Mug"
    click_button "add-to-cart-button"
    page.should have_content('"cart":{"total":"19.99"')
  end

  it "includes the search tag on the results page" do
    visit spree.root_path
    fill_in "keywords", :with => 'mug'
    click_button "Search"
    page.should have_content('"search":{"keyword":"mug"}')
  end

end