require 'spec_helper'

describe "Visiting Products" do
  include_context "custom products"

  before(:each) do
    visit spree.root_path
  end

  it "should be able to show the shopping cart after adding a product to it" do
    click_link "Ruby on Rails Ringer T-Shirt"

    page.should have_content("$19.99")

    click_button 'add-to-cart-button'
    page.should have_content("Shopping Cart")
  end

  it "should be able to search for a product" do
    fill_in "keywords", :with => "shirt"
    click_button "Search"

    page.all('ul.product-listing li').size.should == 1
  end

  it "should be able to visit brand Ruby on Rails" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }

    page.all('ul.product-listing li').size.should == 7
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    array = ["Ruby on Rails Bag",
     "Ruby on Rails Baseball Jersey",
     "Ruby on Rails Jr. Spaghetti",
     "Ruby on Rails Mug",
     "Ruby on Rails Ringer T-Shirt",
     "Ruby on Rails Stein",
     "Ruby on Rails Tote"]
    tmp.sort!.should == array
  end

  it "should be able to visit brand Ruby" do
    within(:css, '#taxonomies') { click_link "Ruby" }

    page.all('ul.product-listing li').size.should == 1
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Ruby Baseball Jersey"]
  end

  it "should be able to visit brand Apache" do
    within(:css, '#taxonomies') { click_link "Apache" }

    page.all('ul.product-listing li').size.should == 1
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Apache Baseball Jersey"]
  end

  it "should be able to visit category Clothing" do
    click_link "Clothing"

    page.all('ul.product-listing li').size.should == 5
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Apache Baseball Jersey",
   "Ruby Baseball Jersey",
   "Ruby on Rails Baseball Jersey",
   "Ruby on Rails Jr. Spaghetti",
   "Ruby on Rails Ringer T-Shirt"]
  end

  it "should be able to visit category Mugs" do
    click_link "Mugs"

    page.all('ul.product-listing li').size.should == 2
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Ruby on Rails Mug", "Ruby on Rails Stein"]
  end

  it "should be able to visit category Bags" do
    click_link "Bags"

    page.all('ul.product-listing li').size.should == 2
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Ruby on Rails Bag", "Ruby on Rails Tote"]
  end

  it "should be able to display products priced under 10 dollars" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_Under_$10.00"
    within(:css, '#sidebar_products_search') { click_button "Search" }
    page.should have_content("No products found")
  end

  it "should be able to display products priced between 15 and 18 dollars" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$15.00_-_$18.00"
    within(:css, '#sidebar_products_search') { click_button "Search" }

    page.all('ul.product-listing li').size.should == 2
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Ruby on Rails Ringer T-Shirt", "Ruby on Rails Stein", "Ruby on Rails Tote"]
  end

  it "should be able to display products priced between 15 and 18 dollars across multiple pages" do
    Spree::Config.products_per_page = 2
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$15.00_-_$18.00"
    within(:css, '#sidebar_products_search') { click_button "Search" }

    page.all('ul.product-listing li').size.should == 4
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Ruby on Rails Ringer T-Shirt", "Ruby on Rails Tote"]
    find('nav.pagination .next a').click
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Ruby on Rails Stein"]
  end

  it "should be able to display products priced 18 dollars and above" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$18.00_-_$20.00"
    check "Price_Range_$20.00_or_over"
    within(:css, '#sidebar_products_search') { click_button "Search" }

    page.all('ul.product-listing li').size.should == 3
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    tmp.sort!.should == ["Ruby on Rails Bag",
                         "Ruby on Rails Baseball Jersey",
                         "Ruby on Rails Jr. Spaghetti"]
  end
end
