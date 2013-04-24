require 'spec_helper'

describe "Header Tags" do
  before do
    @product = create(:product, :name => "RoR Mug")

    Spree::DashConfiguration.new.app_id = 1111
    Spree::DashConfiguration.new.site_id = 2222
    Spree::DashConfiguration.new.token = "test_token"
  end

  let(:analytics) { page.find("script#analytics") }

  it "includes the site_id on the home page" do
    visit spree.root_path
    jirafe = analytics.text =~ /jirafe= \{"id":"2222"\}/
    jirafe.should_not be_nil
  end

  it "includes the product tag on the product page" do
    visit spree.root_path
    click_link "RoR Mug"
    product = analytics.text =~ /"product":\{.*?"name":"RoR Mug".*?\}/
    product.should_not be_nil
  end

  it "includes the cart tag on the cart page" do
    visit spree.root_path
    click_link "RoR Mug"
    click_button "add-to-cart-button"
    cart = analytics.text =~ /"cart":\{.*?"total":"19.99".*?\}/
    cart.should_not be_nil
  end

  it "includes the search tag on the results page" do
    visit spree.root_path
    fill_in "keywords", :with => 'mug'
    click_button "Search"
    search = analytics.text =~ /"search":\{.*?"keyword":"mug".*?\}/
    search.should_not be_nil
  end

end
