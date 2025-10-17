require 'spec_helper'

RSpec.describe 'Product detail page', type: :feature do
  let(:store) { Spree::Store.default }

  let(:brand_taxonomy) { store.taxonomies.find_by(name: 'Brands') || create(:taxonomy, name: 'Brands', store: store) }
  let(:brand) { create(:taxon, taxonomy: brand_taxonomy) }

  let(:categories_taxonomy) { store.taxonomies.find_by(name: 'Categories') || create(:taxonomy, name: 'Categories', store: store) }
  let(:men) { create(:taxon, name: 'Men', taxonomy: categories_taxonomy) }
  let(:clothing) { create(:taxon, name: 'Clothing', parent: men, taxonomy: categories_taxonomy) }
  let(:shoes) { create(:taxon, name: 'Shoes', parent: clothing, taxonomy: categories_taxonomy) }

  let!(:product) { create(:product_in_stock, taxons: [shoes, brand], description: 'Product description', price: 100.0, stores: [store]) }

  let!(:color) { create(:option_type, name: 'color', presentation: 'Color') }
  let!(:black) { create(:option_value, option_type: color, name: 'black', presentation: 'Black') }
  let!(:red) { create(:option_value, option_type: color, name: 'red', presentation: 'Red') }
  let!(:white) { create(:option_value, option_type: color, name: 'white', presentation: 'White') }

  let!(:size) { create(:option_type, name: 'size', presentation: 'Size') }
  let!(:small) { create(:option_value, option_type: size, name: 's', presentation: 'S') }
  let!(:medium) { create(:option_value, option_type: size, name: 'm', presentation: 'M') }
  let!(:large) { create(:option_value, option_type: size, name: 'l', presentation: 'L') }

  let!(:material) { create(:option_type, name: 'material', presentation: 'Material') }
  let!(:cotton) { create(:option_value, option_type: material, name: 'cotton', presentation: 'Cotton') }
  let!(:silk) { create(:option_value, option_type: material, name: 'silk', presentation: 'Silk') }
  let!(:wool) { create(:option_value, option_type: material, name: 'wool', presentation: 'Wool') }

  let(:turbo_frame) { "turbo-frame#main-product-#{product.id}" }

  before do
    visit spree.product_path(product)
  end

  it 'shows product name' do
    within turbo_frame do |c|
      expect(c).to have_text(product.name)
    end
  end

  it 'shows quantity selector' do
    within turbo_frame do |c|
      expect(c).to have_css('div[data-controller="quantity-picker"]')
    end
  end

  it 'show add to cart button' do
    within turbo_frame do |c|
      expect(c).to have_button(Spree.t(:add_to_cart))
    end
  end

  shared_examples 'can be added to cart' do
    it 'works', js: true do
      expect(page).to have_button(Spree.t(:add_to_cart))
      within turbo_frame do
        click_on Spree.t(:add_to_cart)
      end
      wait_for_turbo
      within 'turbo-frame#cart_summary' do |c|
        expect(c).to have_content("Total\n$#{product.price_in('USD').amount}")
      end
    end
  end

  context 'when there is only master variant' do
    shared_examples 'variant picker is not present' do
      it do
        within turbo_frame do |c|
          expect(c).not_to have_css('div#product-variant-picker')
        end
      end
    end

    context 'when product is out of stock' do
      before do
        product.stock_items.update_all(count_on_hand: 0, backorderable: false)
        visit spree.product_path(product)
      end

      it_behaves_like 'variant picker is not present'

      it 'shows product\'s price' do
        within turbo_frame do |c|
          expect(c).to have_content("$#{product.price_in('USD').amount}")
        end
      end

      it 'has `Notify me when available` instead of add to cart button' do
        within turbo_frame do
          add_to_cart_button = first("button[data-product-form-target='submit']")
          expect(add_to_cart_button.text).to eq Spree.t(:notify_me_when_available)
        end
      end

      xit 'can be added to waitlist', js: true do
        within turbo_frame do |_c|
          expect(page).to have_button(Spree.t(:notify_me_when_available))
          click_on Spree.t(:notify_me_when_available)
          fill_in Spree.t(:email), with: 'customer@email.com'
          click_on Spree.t(:add_to_waitlist)
          wait_for_turbo

          waitlist = Spree::Waitlist.last
          expect(waitlist.email).to eq 'customer@email.com'
          expect(waitlist.variant_id).to eq product.master.id
        end
      end

      context 'when master variant is backorderable', js: true do
        before do
          product.stock_items.update_all(count_on_hand: 0, backorderable: true)
          visit spree.product_path(product)
        end

        it_behaves_like 'can be added to cart'
      end
    end

    context 'when product is in stock' do
      before do
        product.stock_items.update_all(count_on_hand: 10, backorderable: false)
        visit spree.product_path(product)
      end

      it_behaves_like 'variant picker is not present'

      it 'shows product\'s price' do
        within turbo_frame do |c|
          expect(c).to have_content("$#{product.price_in('USD').amount}")
        end
      end

      it_behaves_like 'can be added to cart'

      it 'cannot add more than available quantity', js: true do
        # Mock store url to match Capybara url for cookie domain
        allow_any_instance_of(Spree::LineItemsController).to receive(:current_store)
          .and_return(store)
        host = Capybara.current_session.server.host
        allow(store).to receive(:url_or_custom_domain).and_return(host)
        # we need to populate cart first
        within turbo_frame do
          fill_in 'quantity', with: 10
          click_on Spree.t(:add_to_cart)
        end

        # refresh page
        page.driver.browser.navigate.refresh

        # set quantity field to 11
        within turbo_frame do
          fill_in 'quantity', with: 10
          click_on Spree.t(:add_to_cart)
        end

        expect(page).to have_content("Quantity selected of \"#{product.name}\" is not available")
      end
    end

    context 'when product has no price' do
      before do
        product.master.prices.destroy_all
        product.stock_items.update_all(count_on_hand: 10, backorderable: false)

        visit spree.product_path(product)
      end

      it 'shows N/A instead' do
        within turbo_frame do |c|
          expect(c).to have_content('N/A')
        end
      end
    end
  end

  context 'when there is only one variant' do
    let!(:variant1) { create(:variant, product: product, option_values: [small, black, cotton]) }

    before do
      create_product_option_types
    end

    shared_examples 'auto selects all options' do
      it do
        within turbo_frame do
          within('#product-variant-picker') do
            expect(page).to have_content('Size: S')
            expect(page).to have_content('Cotton')
          end
          expect(find_color_option('black')).to be_checked
        end
      end
    end

    context 'when variant is in stock' do
      before do
        variant1.stock_items.update_all(count_on_hand: 10, backorderable: false)
        visit spree.product_path(product)
      end

      it_behaves_like 'auto selects all options'
      it_behaves_like 'can be added to cart'

      it 'shows variant\'s price' do
        within turbo_frame do |c|
          expect(c).to have_content("$#{variant1.price_in('USD').amount}")
        end
      end
    end

    context 'when variant is out of stock' do
      before do
        variant1.stock_items.update_all(count_on_hand: 0, backorderable: false)
        visit spree.product_path(product)
      end

      it_behaves_like 'auto selects all options'

      it 'shows variant\'s price' do
        within turbo_frame do |c|
          expect(c).to have_content("$#{variant1.price_in('USD').amount}")
        end
      end

      xit 'can be added to waitlist', js: true do
        within turbo_frame do |_c|
          click_on Spree.t(:notify_me_when_available)
          fill_in Spree.t(:email), with: 'customer@email.com'
          click_on Spree.t(:add_to_waitlist)
          wait_for_turbo

          waitlist = Spree::Waitlist.last
          expect(waitlist.email).to eq 'customer@email.com'
          expect(waitlist.variant_id).to eq variant1.id
        end
      end

      context 'when variant is backorderable' do
        before do
          variant1.stock_items.update_all(count_on_hand: 0, backorderable: true)
          visit spree.product_path(product)
        end

        it_behaves_like 'can be added to cart'
      end
    end

    context 'when variant has no price' do
      before do
        variant1.prices.destroy_all
        variant1.stock_items.update_all(count_on_hand: 10, backorderable: false)

        visit spree.product_path(product)
      end

      it 'shows N/A instead' do
        within turbo_frame do |c|
          expect(c).to have_content('N/A')
        end
      end
    end
  end

  context 'when there is more variants' do
    let!(:variant1) { create(:variant, product: product, option_values: [small, black, cotton]) }
    let!(:variant2) { create(:variant, product: product, option_values: [medium, red, wool]) }
    let!(:variant3) { create(:variant, product: product, option_values: [large, white, silk]) }

    before do
      create_product_option_types
    end

    shared_examples 'auto selects color' do
      it do
        within turbo_frame do
          expect(find_color_option('black')).to be_checked
        end
      end
    end

    context 'when all variants are oos' do
      before do
        product.stock_items.update_all(count_on_hand: 0, backorderable: false)
        variant2.prices.update_all(amount: 40)
        visit spree.product_path(product)
      end

      it_behaves_like 'auto selects color'

      it 'shows first variant\'s price' do
        within turbo_frame do |c|
          expect(c).to have_content("$#{variant1.price_in('USD').amount}")
        end
      end

      it 'should show `Notify me when available`' do
        within turbo_frame do |c|
          expect(c).to have_button Spree.t(:notify_me_when_available)
          expect(c).not_to have_button Spree.t(:add_to_cart)
        end
      end

      xcontext 'when selecting options', js: true do
        it 'should render button to add variant to waitlist' do
          within turbo_frame do |c|
            find_color_option('red').ancestor('label').click
            wait_for_turbo

            click_on 'choose Size'
            find('label', text: 'M', visible: true).click
            wait_for_turbo

            click_on 'choose Material'
            find('label', text: 'Wool', visible: true).click
            wait_for_turbo

            expect(c).to have_content('$40')

            expect(c).to have_button Spree.t(:notify_me_when_available)
            expect(c).not_to have_button Spree.t(:add_to_cart)
          end
        end

        xit 'can be added to waitlist' do
          within turbo_frame do |_c|
            wait_for_turbo

            click_on 'choose Size'
            find('label', text: 'M', visible: true).click
            wait_for_turbo

            click_on 'choose Material'
            find('label', text: 'Wool', visible: true).click
            wait_for_turbo

            click_on Spree.t(:notify_me_when_available)
            fill_in Spree.t(:email), with: 'customer@email.com'
            click_on Spree.t(:add_to_waitlist)
            wait_for_turbo

            waitlist = Spree::Waitlist.last
            expect(waitlist.email).to eq 'customer@email.com'
            expect(waitlist.variant_id).to eq variant1.id
          end
        end
      end
    end

    context 'when all variants are purchasable' do
      before do
        product.stock_items.update_all(count_on_hand: 10, backorderable: false)
        variant2.prices.update_all(amount: 40)
        visit spree.product_path(product)
      end

      it_behaves_like 'auto selects color'

      it 'shows first variant\'s price' do
        within turbo_frame do |c|
          expect(c).to have_content("$#{variant1.price_in('USD').amount}")
        end
      end

      it 'should show `please select all options`' do
        within turbo_frame do |c|
          expect(c).to have_button Spree.t('storefront.variant_picker.please_choose_all_options')
          expect(c).not_to have_button Spree.t(:add_to_cart)
        end
      end

      context 'when there is only one option not selected', js: true do
        it 'should show `please select {option.presentation}`' do
          within turbo_frame do |c|
            find_color_option('red').ancestor('label').click
            wait_for_turbo

            click_on 'choose Size'
            find('label', text: 'M', visible: true).click
            wait_for_turbo
            expect(c).not_to have_content 'Please choose Size', wait: 5.seconds

            expect(c).to have_button 'Please choose Material'
          end
        end
      end

      context 'when selecting options', js: true do
        it 'should render button to add variant to cart' do
          within turbo_frame do |c|
            find_color_option('red').ancestor('label').click
            wait_for_turbo

            first('button', text: 'Please choose Size').click
            find('label', text: 'M', visible: true).click
            wait_for_turbo

            first('button', text: 'Please choose Material').click
            find('label', text: 'Wool', visible: true).click
            wait_for_turbo

            expect(c).to have_content('$40')

            expect(c).to have_button Spree.t(:add_to_cart)
            expect(c).not_to have_button Spree.t(:notify_me_when_available)
          end
        end
      end
    end

    context 'when some variants are purchasable' do
      before do
        product.stock_items.update_all(count_on_hand: 10, backorderable: false)
        variant2.prices.update_all(amount: 40)
        variant3.prices.update_all(amount: 50)
        variant3.stock_items.update_all(count_on_hand: 0, backorderable: false)
        visit spree.product_path(product)
      end

      it_behaves_like 'auto selects color'

      it 'shows first variant\'s price' do
        within turbo_frame do |c|
          expect(c).to have_content("$#{variant1.price_in('USD').amount}")
        end
      end

      it 'should show `please select all options`' do
        within turbo_frame do |c|
          expect(c).to have_button Spree.t('storefront.variant_picker.please_choose_all_options')
          expect(c).not_to have_button Spree.t(:add_to_cart)
        end
      end

      context 'when selecting option value which has `:` in the `name`', js: true do
        before do
          visit spree.product_path(product)
        end

        let!(:small) { create(:option_value, option_type: size, name: 'small: xs', presentation: 'Small: XS') }

        it 'should work' do
          within turbo_frame do |c|
            find_color_option('black').ancestor('label').click
            wait_for_turbo

            first('button', text: 'choose Size').click
            find('label', text: 'Small: XS', visible: true).click
            wait_for_turbo

            expect(c).to have_button 'choose Material', disabled: false, wait: 5.seconds
            # Close any open dropdowns first to avoid click interception
            page.execute_script("document.querySelectorAll('[data-dropdown-target=\"menu\"]').forEach(el => el.classList.add('hidden'))")
            find('button', text: 'choose Material').click
            find('label', text: 'Cotton', visible: true).click
            wait_for_turbo

            expect(c).to have_content('$19.99')

            expect(c).to have_button Spree.t(:add_to_cart)
            expect(c).not_to have_button Spree.t(:notify_me_when_available)

            click_on Spree.t(:add_to_cart)
          end

          within 'turbo-frame#cart_summary' do |c|
            expect(c).to have_content("Total\n$19.99")
          end
        end
      end

      xcontext 'when selecting oos variant', js: true do
        it 'should render button to add variant to waitlist' do
          within turbo_frame do |c|
            find_color_option('white').ancestor('label').click
            wait_for_turbo

            within '#product-variant-picker' do
              click_on 'choose Size'
              find('label', text: 'L', visible: true).click
              wait_for_turbo

              click_on 'choose Material'
              find('label', text: 'Silk', visible: true).click
            end

            wait_for_turbo

            expect(c).to have_content('$50')

            expect(c).to have_button Spree.t(:notify_me_when_available)
            expect(c).not_to have_button Spree.t(:add_to_cart)
          end
        end

        xit 'can be added to waitlist' do
          within turbo_frame do |_c|
            find_color_option('white').ancestor('label').click
            wait_for_turbo

            within '#product-variant-picker' do
              click_on 'choose Size'
              find('label', text: 'L', visible: true).click
              wait_for_turbo

              click_on 'choose Material'
              find('label', text: 'Silk', visible: true).click
            end

            wait_for_turbo

            click_on Spree.t(:notify_me_when_available)
            fill_in Spree.t(:email), with: 'customer@email.com'
            click_on Spree.t(:add_to_waitlist)
            wait_for_turbo

            waitlist = Spree::Waitlist.last
            expect(waitlist.email).to eq 'customer@email.com'
            expect(waitlist.variant_id).to eq variant3.id
          end
        end
      end

      context 'when selecting purchasable variant', js: true do
        it 'should render button to add variant to cart' do
          within turbo_frame do |c|
            find_color_option('red').ancestor('label').click
            wait_for_turbo

            click_on 'Please choose Size'
            find('label', text: 'M', visible: true).click
            wait_for_turbo
            expect(c).not_to have_content 'Please choose Size', wait: 5.seconds

            first('button', text: 'Please choose Material').click
            find('label', text: 'Wool', visible: true).click
            wait_for_turbo

            expect(c).to have_content('$40')

            expect(c).to have_button Spree.t(:add_to_cart)
            expect(c).not_to have_button Spree.t(:notify_me_when_available)
          end
        end
      end
    end

    context 'when all variants have no price' do
      before do
        variant1.prices.destroy_all
        variant2.prices.destroy_all
        variant3.prices.destroy_all

        variant1.stock_items.update_all(count_on_hand: 10, backorderable: false)
        variant2.stock_items.update_all(count_on_hand: 10, backorderable: false)
        variant3.stock_items.update_all(count_on_hand: 10, backorderable: false)

        visit spree.product_path(product)
      end

      it 'shows N/A instead' do
        within turbo_frame do |c|
          expect(c).to have_content('N/A')
        end
      end
    end
  end

  context 'when variant has only one value in secondary option and first option is color' do
    let!(:variant1) { create(:variant, product: product, option_values: [small, black]) }
    let!(:variant2) { create(:variant, product: product, option_values: [small, red]) }
    let!(:variant3) { create(:variant, product: product, option_values: [small, white]) }

    before do
      create(:product_option_type, product: product, option_type: color)
      create(:product_option_type, product: product, option_type: size)
    end

    context 'when variants are oos' do
      before do
        product.stock_items.update_all(count_on_hand: 0, backorderable: false)
        visit spree.product_path(product)
      end

      it 'should auto select second option' do
        within turbo_frame do
          expect(find_color_option('black')).to be_present
          expect(find_color_option('red')).to be_present
          expect(find_color_option('white')).to be_present

          within('#product-variant-picker') do
            expect(page).to have_content('Size: S')
          end
        end
      end
    end

    context 'when variants are purchasable' do
      before do
        product.stock_items.update_all(count_on_hand: 10, backorderable: false)
        visit spree.product_path(product)
      end

      it 'should auto select second option' do
        within turbo_frame do
          expect(find_color_option('black')).to be_present
          expect(find_color_option('red')).to be_present
          expect(find_color_option('white')).to be_present

          within('#product-variant-picker') do
            expect(page).to have_content('Size: S')
          end
        end
      end
    end
  end

  it 'shows taxon tree in breadcrumbs' do
    within('nav#breadcrumbs') do
      expect(page).to have_text('Men')
      expect(page).to have_text('Clothing')
      expect(page).to have_text('Shoes')
      expect(page).to have_text(product.name)
    end
  end

  it 'shows product description' do
    within turbo_frame do |c|
      expect(c).to have_text(product.description)
    end
  end

  def create_product_option_types
    create(:product_option_type, product: product, option_type: color)
    create(:product_option_type, product: product, option_type: size)
    create(:product_option_type, product: product, option_type: material)
  end

  def find_option(label)
    within('#product-variant-picker') do
      expect(page).to have_content(label)
    end
  end

  def find_color_option(color_name)
    find("input[name='Color'][value='#{color_name}']", visible: true)
  end
end
