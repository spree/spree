# encoding: utf-8
require 'spec_helper'

describe "Visiting Products", type: :feature, inaccessible: true do
  include_context "custom products"

  before(:each) do
    visit spree.root_path
  end

  it "should be able to show the shopping cart after adding a product to it" do
    click_link "Ruby on Rails Ringer T-Shirt"
    expect(page).to have_content("$19.99")

    click_button 'add-to-cart-button'
    expect(page).to have_content("Shopping Cart")
  end

  context "using Russian Rubles as a currency" do
    before do
      Spree::Config[:currency] = "RUB"
    end

    let!(:product) do
      product = Spree::Product.find_by_name("Ruby on Rails Ringer T-Shirt")
      product.price = 19.99
      product.tap(&:save)
    end

    # Regression tests for #2737
    context "uses руб as the currency symbol" do
      it "on products page" do
        visit spree.root_path
        within("#product_#{product.id}") do
          within(".price") do
            expect(page).to have_content("руб19.99")
          end
        end
      end

      it "on product page" do
        visit spree.product_path(product)
        within(".price") do
          expect(page).to have_content("руб19.99")
        end
      end

      it "when adding a product to the cart", :js => true do
        visit spree.product_path(product)
        click_button "Add To Cart"
        click_link "Home"
        within(".cart-info") do
          expect(page).to have_content("РУБ19.99")
        end
      end

      it "when on the 'address' state of the cart" do
        visit spree.product_path(product)
        click_button "Add To Cart"
        click_button "Checkout"
        within("tr[data-hook=item_total]") do
          expect(page).to have_content("руб19.99")
        end
      end
    end
  end

  it "should be able to search for a product" do
    fill_in "keywords", :with => "shirt"
    click_button "Search"

    expect(page.all('ul.product-listing li').size).to eq(1)
  end

  context "a product with variants" do
    let(:product) { Spree::Product.find_by_name("Ruby on Rails Baseball Jersey") }
    let(:option_value) { create(:option_value) }
    let!(:variant) { product.variants.create!(:price => 5.59) }

    before do
      Spree::Config[:display_currency] = true
      # Need to have two images to trigger the error
      image = File.open(File.expand_path('../../fixtures/thinking-cat.jpg', __FILE__))
      product.images.create!(:attachment => image)
      product.images.create!(:attachment => image)

      product.option_types << option_value.option_type
      variant.option_values << option_value
    end

    it "should be displayed" do
      expect { click_link product.name }.to_not raise_error
    end

    it "displays price of first variant listed", js: true do
      click_link product.name
      within("#product-price") do
        expect(page).to have_content variant.price
        expect(page).not_to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display out of stock for master product" do
      product.master.stock_items.update_all count_on_hand: 0, backorderable: false

      click_link product.name
      within("#product-price") do
        expect(page).not_to have_content Spree.t(:out_of_stock)
      end
    end

    # Regression test for #4342
    it "does not fail when display_currency is true" do
      Spree::Config[:display_currency] = true
      click_link product.name
      within("#cart-form") do
        find('input[type=radio]')
      end
    end
  end

  context "a product with variants, images only for the variants" do
    let(:product) { Spree::Product.find_by_name("Ruby on Rails Baseball Jersey") }

    before do
      image = File.open(File.expand_path('../../fixtures/thinking-cat.jpg', __FILE__))
      v1 = product.variants.create!(price: 9.99)
      v2 = product.variants.create!(price: 10.99)
      v1.images.create!(attachment: image)
      v2.images.create!(attachment: image)
    end

    it "should not display no image available" do
      visit spree.root_path
      expect(page).to have_xpath("//img[contains(@src,'thinking-cat')]")
    end
  end

  it "should be able to hide products without price" do
    expect(page.all('ul.product-listing li').size).to eq(9)
    Spree::Config.show_products_without_price = false
    Spree::Config.currency = "CAN"
    visit spree.root_path
    expect(page.all('ul.product-listing li').size).to eq(0)
  end


  it "should be able to display products priced under 10 dollars" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_Under_$10.00"
    within(:css, '#sidebar_products_search') { click_button "Search" }
    expect(page).to have_content("No products found")
  end

  it "should be able to display products priced between 15 and 18 dollars" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$15.00_-_$18.00"
    within(:css, '#sidebar_products_search') { click_button "Search" }

    expect(page.all('ul.product-listing li').size).to eq(3)
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    expect(tmp.sort!).to eq(["Ruby on Rails Mug", "Ruby on Rails Stein", "Ruby on Rails Tote"])
  end

  it "should be able to display products priced between 15 and 18 dollars across multiple pages" do
    Spree::Config.products_per_page = 2
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$15.00_-_$18.00"
    within(:css, '#sidebar_products_search') { click_button "Search" }

    expect(page.all('ul.product-listing li').size).to eq(2)
    products = page.all('ul.product-listing li a[itemprop=name]')
    expect(products.count).to eq(2)

    find('nav.pagination .next a').click
    products = page.all('ul.product-listing li a[itemprop=name]')
    expect(products.count).to eq(1)
  end

  it "should be able to display products priced 18 dollars and above" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$18.00_-_$20.00"
    check "Price_Range_$20.00_or_over"
    within(:css, '#sidebar_products_search') { click_button "Search" }

    expect(page.all('ul.product-listing li').size).to eq(4)
    tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
    tmp.delete("")
    expect(tmp.sort!).to eq(["Ruby on Rails Bag",
                         "Ruby on Rails Baseball Jersey",
                         "Ruby on Rails Jr. Spaghetti",
                         "Ruby on Rails Ringer T-Shirt"])
  end

  it "should be able to put a product without a description in the cart" do
    product = FactoryGirl.create(:base_product, :description => nil, :name => 'Sample', :price => '19.99')
    visit spree.product_path(product)
    expect(page).to have_content "This product has no description"
    click_button 'add-to-cart-button'
    expect(page).to have_content "This product has no description"
  end

  it "shouldn't be able to put a product without a current price in the cart" do
    product = FactoryGirl.create(:base_product, :description => nil, :name => 'Sample', :price => '19.99')
    Spree::Config.currency = "CAN"
    Spree::Config.show_products_without_price = true
    visit spree.product_path(product)
    expect(page).to have_content "This product is not available in the selected currency."
    expect(page).not_to have_content "add-to-cart-button"
  end

  it "should return the correct title when displaying a single product" do
    product = Spree::Product.find_by_name("Ruby on Rails Baseball Jersey")
    click_link product.name

    within("div#product-description") do
      within("h1.product-title") do
        expect(page).to have_content("Ruby on Rails Baseball Jersey")
      end
    end
  end

  it "should return the correct title when displaying a single product" do
    product = Spree::Product.find_by_name("Ruby on Rails Baseball Jersey")
    click_link product.name

    within("div#product-description") do
      within("h1.product-title") do
        expect(page).to have_content("Ruby on Rails Baseball Jersey")
      end
    end
  end
end
