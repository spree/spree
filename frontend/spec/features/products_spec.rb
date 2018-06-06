require 'spec_helper'

describe 'Visiting Products', type: :feature, inaccessible: true do
  include_context 'custom products'

  let(:store_name) do
    ((first_store = Spree::Store.first) && first_store.name).to_s
  end

  before do
    visit spree.root_path
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with(:SPREE_USE_PAPERCLIP).and_return(true)
  end

  it 'is able to show the shopping cart after adding a product to it' do
    click_link 'Ruby on Rails Ringer T-Shirt'
    expect(page).to have_content('$19.99')

    click_button 'add-to-cart-button'
    expect(page).to have_content('Shopping Cart')
  end

  describe 'correct displaying of microdata' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Ringer T-Shirt') }

    it 'on products page' do
      within("#product_#{product.id}") do
        within('[itemprop=name]') do
          expect(page).to have_content('Ruby on Rails Ringer T-Shirt')
        end
        expect(page).to have_css("[itemprop='price'][content='19.99']")
        expect(page).to have_css("[itemprop='priceCurrency'][content='USD']")
        expect(page).to have_css("[itemprop='url'][href='/products/ruby-on-rails-ringer-t-shirt']")
        expect(page).to have_css("[itemprop='image'][src*='/assets/noimage/small']")
      end
    end

    it 'on product page' do
      click_link product.name
      within('[data-hook=product_show]') do
        within('[itemprop=name]') do
          expect(page).to have_content('Ruby on Rails Ringer T-Shirt')
        end
        expect(page).to have_css("[itemprop='price'][content='19.99']")
        expect(page).to have_css("[itemprop='priceCurrency'][content='USD']")
        expect(page).to have_css("[itemprop='image'][src*='/assets/noimage/product']")
      end
    end
  end

  describe 'meta tags and title' do
    let(:jersey) { Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey') }
    let(:metas) { { meta_description: 'Brand new Ruby on Rails Jersey', meta_title: 'Ruby on Rails Baseball Jersey Buy High Quality Geek Apparel', meta_keywords: 'ror, jersey, ruby' } }

    it 'returns the correct title when displaying a single product' do
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey - ' + store_name)
      within('div#product-description') do
        within('h1.product-title') do
          expect(page).to have_content('Ruby on Rails Baseball Jersey')
        end
      end
    end

    it 'displays metas' do
      jersey.update_attributes metas
      click_link jersey.name
      expect(page).to have_meta(:description, 'Brand new Ruby on Rails Jersey')
      expect(page).to have_meta(:keywords, 'ror, jersey, ruby')
    end

    it 'displays title if set' do
      jersey.update_attributes metas
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey Buy High Quality Geek Apparel')
    end

    it "doesn't use meta_title as heading on page" do
      jersey.update_attributes metas
      click_link jersey.name
      within('h1') do
        expect(page).to have_content(jersey.name)
        expect(page).not_to have_content(jersey.meta_title)
      end
    end

    it 'uses product name in title when meta_title set to empty string' do
      jersey.update_attributes meta_title: ''
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey - ' + store_name)
    end
  end

  context 'using Russian Rubles as a currency' do
    before do
      Spree::Config[:currency] = 'RUB'
    end

    let!(:product) do
      product = Spree::Product.find_by(name: 'Ruby on Rails Ringer T-Shirt')
      product.price = 19.99
      product.tap(&:save)
    end

    # Regression tests for #2737
    context 'uses руб as the currency symbol' do
      it 'on products page' do
        visit spree.root_path
        within("#product_#{product.id}") do
          within('.price') do
            expect(page).to have_content('19.99 ₽')
          end
        end
      end

      it 'on product page' do
        visit spree.product_path(product)
        within('.price') do
          expect(page).to have_content('19.99 ₽')
        end
      end

      it 'when adding a product to the cart', js: true do
        visit spree.product_path(product)
        click_button 'Add To Cart'
        click_link 'Home'
        within('.cart-info') do
          expect(page).to have_content('19.99 ₽')
        end
      end

      it "when on the 'address' state of the cart", js: true do
        visit spree.product_path(product)
        click_button 'Add To Cart'
        click_button 'Checkout'
        fill_in 'order_email', with: 'test@example.com'
        click_button 'Continue'
        within('tr[data-hook=item_total]') do
          expect(page).to have_content('19.99 ₽')
        end
      end
    end
  end

  it 'is able to search for a product' do
    fill_in 'keywords', with: 'shirt'
    click_button 'Search'

    expect(page.all('#products .product-list-item').size).to eq(1)
  end

  context 'a product with variants' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey') }
    let(:option_value) { create(:option_value) }
    let!(:variant) { build(:variant, price: 5.59, product: product, option_values: []) }

    before do
      # Need to have two images to trigger the error
      image = File.open(File.expand_path('../../fixtures/thinking-cat.jpg', __FILE__))

      product.images.create!(attachment: image)
      product.images.create!(attachment: image)

      product.option_types << option_value.option_type
      variant.option_values << option_value
      variant.save!
    end

    it 'is displayed' do
      expect { click_link product.name }.not_to raise_error
    end

    it 'displays price of first variant listed', js: true do
      click_link product.name
      within('#product-price') do
        expect(page).to have_content variant.price
        expect(page).not_to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display out of stock for master product" do
      product.master.stock_items.update_all count_on_hand: 0, backorderable: false

      click_link product.name
      within('#product-price') do
        expect(page).not_to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display cart form if all variants (including master) are out of stock" do
      product.variants_including_master.each { |v| v.stock_items.update_all count_on_hand: 0, backorderable: false }

      click_link product.name
      within('[data-hook=product_price]') do
        expect(page).not_to have_content Spree.t(:add_to_cart)
      end
    end
  end

  context 'a product with variants, images only for the variants' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey') }
    let(:variant1) { create(:variant, product: product, price: 9.99) }
    let(:variant2) { create(:variant, product: product, price: 10.99) }

    before do
      image = File.open(File.expand_path('../../fixtures/thinking-cat.jpg', __FILE__))
      variant1.images.create!(attachment: image)
      variant2.images.create!(attachment: image)
    end

    it 'does not display no image available' do
      visit spree.root_path
      expect(page).to have_xpath("//img[contains(@src,'thinking-cat')]")
    end
  end

  context 'an out of stock product without variants' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Tote') }

    before do
      product.master.stock_items.update_all count_on_hand: 0, backorderable: false
    end

    it 'does display out of stock for master product' do
      click_link product.name
      within('#product-price') do
        expect(page).to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display cart form if master is out of stock" do
      click_link product.name
      within('[data-hook=product_price]') do
        expect(page).not_to have_content Spree.t(:add_to_cart)
      end
    end
  end

  context 'product with taxons' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Tote') }
    let(:taxon) { product.taxons.first }

    it 'displays breadcrumbs for the default taxon when none selected' do
      click_link product.name
      within('#breadcrumbs') do
        expect(page).to have_content taxon.name
      end
    end

    it 'displays selected taxon in breadcrumbs' do
      taxon = Spree::Taxon.last
      product.taxons << taxon
      product.save!
      visit '/t/' + taxon.to_param
      click_link product.name
      within('#breadcrumbs') do
        expect(page).to have_content taxon.name
      end
    end
  end

  it 'is able to hide products without price' do
    expect(page.all('#products .product-list-item').size).to eq(9)
    Spree::Config.show_products_without_price = false
    Spree::Config.currency = 'CAN'
    visit spree.root_path
    expect(page.all('#products .product-list-item').size).to eq(0)
  end

  it 'is able to display products priced under 10 dollars' do
    within(:css, '#taxonomies') { click_link 'Ruby on Rails' }
    check 'Price_Range_Under_$10.00'
    within(:css, '#sidebar_products_search') { click_button 'Search' }
    expect(page).to have_content('No products found')
  end

  it 'is able to display products priced between 15 and 18 dollars' do
    within(:css, '#taxonomies') { click_link 'Ruby on Rails' }
    check 'Price_Range_$15.00_-_$18.00'
    within(:css, '#sidebar_products_search') { click_button 'Search' }

    expect(page.all('#products .product-list-item').size).to eq(3)
    tmp = page.all('#products .product-list-item a').map(&:text).flatten.compact
    tmp.delete('')
    expect(tmp.sort!).to eq(['Ruby on Rails Mug', 'Ruby on Rails Stein', 'Ruby on Rails Tote'])
  end

  it 'is able to display products priced between 15 and 18 dollars across multiple pages' do
    Spree::Config.products_per_page = 2
    within(:css, '#taxonomies') { click_link 'Ruby on Rails' }
    check 'Price_Range_$15.00_-_$18.00'
    within(:css, '#sidebar_products_search') { click_button 'Search' }

    expect(page.all('#products .product-list-item').size).to eq(2)
    products = page.all('#products .product-list-item span[itemprop=name]')
    expect(products.count).to eq(2)

    find('.pagination .next a').click
    products = page.all('#products .product-list-item span[itemprop=name]')
    expect(products.count).to eq(1)
  end

  it 'is able to display products priced 18 dollars and above' do
    within(:css, '#taxonomies') { click_link 'Ruby on Rails' }
    check 'Price_Range_$18.00_-_$20.00'
    check 'Price_Range_$20.00_or_over'
    within(:css, '#sidebar_products_search') { click_button 'Search' }

    expect(page.all('#products .product-list-item').size).to eq(4)
    tmp = page.all('#products .product-list-item a').map(&:text).flatten.compact
    tmp.delete('')
    expect(tmp.sort!).to eq(['Ruby on Rails Bag',
                             'Ruby on Rails Baseball Jersey',
                             'Ruby on Rails Jr. Spaghetti',
                             'Ruby on Rails Ringer T-Shirt'])
  end

  it 'is able to put a product without a description in the cart' do
    product = FactoryBot.create(:base_product, description: nil, name: 'Sample', price: '19.99')
    visit spree.product_path(product)
    expect(page).to have_content 'This product has no description'
    click_button 'add-to-cart-button'
    expect(page).to have_content 'This product has no description'
  end

  it 'is not able to put a product without a current price in the cart' do
    product = FactoryBot.create(:base_product, description: nil, name: 'Sample', price: '19.99')
    Spree::Config.currency = 'CAN'
    Spree::Config.show_products_without_price = true
    visit spree.product_path(product)
    expect(page).to have_content 'This product is not available in the selected currency.'
    expect(page).not_to have_content 'add-to-cart-button'
  end

  it 'returns the correct title when displaying a single product' do
    product = Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey')
    click_link product.name

    within('div#product-description') do
      within('h1.product-title') do
        expect(page).to have_content('Ruby on Rails Baseball Jersey')
      end
    end
  end
end
