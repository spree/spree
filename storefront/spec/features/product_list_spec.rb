require 'spec_helper'

RSpec.describe 'Product list', type: :feature, js: true, job: true do
  let!(:product1) { create(:product, name: 'Running Jacket', price: 20.00, available_on: Time.current - 4.days) }
  let!(:product2) { create(:product, name: 'Waterproof Shoes', price: 10.00, available_on: Time.current - 3.days) }
  let!(:product3) { create(:product, name: 'Warming gloves', price: 30.00, available_on: Time.current - 2.days) }
  let!(:product4) do
    create(:product, name: 'Product out of stock', available_on: Time.current - 1.day) do |product|
      product.master.stock_items.update_all(backorderable: false)
      product.touch
    end
  end
  let!(:product5) do
    product = create(:product, name: 'Product without price')
    product.master.prices.delete_all
    product
  end
  let!(:product6) { create(:product, name: 'Product for free', price: 0.00, available_on: Date.today) }

  let!(:size) { Spree::OptionType.find_by(name: 'size') || create(:option_type, :size) }
  let!(:small) { create(:option_value, option_type: size, name: 'small', presentation: 'Small') }
  let!(:medium) { create(:option_value, option_type: size, name: 'medium', presentation: 'Medium') }
  let!(:large) { create(:option_value, option_type: size, name: 'large', presentation: 'Large') }

  let(:store) { Spree::Store.default }

  let!(:product_option_type1) { create(:product_option_type, product: product1, option_type: size) }

  it 'does not include products with prices not set' do
    visit spree.products_path

    expect(page).not_to have_content('Product without price')
  end

  describe 'prices' do
    before { visit spree.products_path }

    context 'when product does not have variants' do
      context 'when not on sale' do
        it 'shows regular price' do
          within("#product-card-#{product1.id}") do
            expect(page).to have_content('$20.00')
          end
        end
      end

      context 'when on sale' do
        before do
          product1.master.prices.update_all(compare_at_amount: 40.00)
          product1.touch
          visit spree.products_path
        end

        it 'shows sale price' do
          within("#product-card-#{product1.id}") do
            expect(page).to have_content('$20.00')
          end
        end

        it 'shows compare at price' do
          within("#product-card-#{product1.id}") do
            expect(page).to have_css('p.line-through', text: '$40.00')
          end
        end
      end
    end

    context 'when product has variants' do
      let!(:variant1) { create(:variant, product: product1, option_values: [small], price: price1) }
      let!(:variant2) { create(:variant, product: product1, option_values: [medium], price: price2) }
      let!(:variant3) { create(:variant, product: product1, option_values: [large], price: price3) }

      before do
        product1.master.prices.delete_all
        visit spree.products_path
      end

      context 'when variants have same prices' do
        let(:price1) { 100.00 }
        let(:price2) { 100.00 }
        let(:price3) { 100.00 }

        it 'shows common price' do
          within("#product-card-#{product1.id}") do
            expect(page).to have_content('$100.00')
          end
        end

        context 'when some variants is on sale' do
          before do
            variant1.prices.update_all(amount: 100.00, compare_at_amount: 120.00)
            variant1.product.touch
            visit spree.products_path
          end

          it 'shows sale price' do
            within("#product-card-#{product1.id}") do
              expect(page).to have_content('$100.00')
            end
          end

          xit 'shows the highest compare at price' do
            within("#product-card-#{product1.id}") do
              expect(page).to have_css('p.line-through', text: '$120.00')
            end
          end

          it 'does not show From phrase' do
            within("#product-card-#{product1.id}") do
              expect(page).not_to have_text('From')
            end
          end
        end
      end

      context 'when variants have different prices' do
        let(:price1) { 100.00 }
        let(:price2) { 150.00 }
        let(:price3) { 200.00 }

        it 'shows From: $100.00' do
          within("#product-card-#{product1.id}") do
            expect(page).to have_text('From: $100.00')
          end
        end

        context 'when some variant is on sale' do
          context 'when its the cheapest variant' do
            before do
              variant2.prices.update_all(amount: 90.00, compare_at_amount: 150.00)
              variant2.product.touch
              visit spree.products_path
            end

            it 'shows From: $90.00' do
              within("#product-card-#{product1.id}") do
                expect(page).to have_text('From: $90.00')
              end
            end

            it 'shows compare at price of the cheapest variant' do
              within("#product-card-#{product1.id}") do
                expect(page).to have_css('p.line-through', text: '$150.00')
              end
            end
          end
        end
      end
    end
  end

  describe 'searching' do
    let!(:products) { create_list(:product, 10, price: 5.00) }

    it do
      visit spree.products_path

      expect(page).to have_content('Running Jacket')
      expect(page).to have_content('Waterproof Shoes')
      expect(page).to have_content('Warming gloves')

      click_on 'Search'
      fill_in('q', with: 'Jacket').send_keys(:enter)

      expect(page).to have_content('Running Jacket')
      expect(page).not_to have_content('Waterproof Shoes')
      expect(page).not_to have_content('Warming gloves')

      # Empty search bar returns all products
      click_on 'Search'
      fill_in('q', with: '').send_keys(:enter)

      expect(page).to have_content('Running Jacket')
      expect(page).to have_content('Waterproof Shoes')
      expect(page).to have_content('Warming gloves')
    end
  end

  describe 'sorting' do
    let!(:completed_order_1) { create(:completed_order_with_totals, variants: [product1.master, product2.master, product3.master, product6.master]) }
    let!(:completed_order_2) { create(:completed_order_with_totals, variants: [product1.master, product2.master, product3.master, product6.master]) }
    let!(:completed_order_3) { create(:completed_order_with_totals, variants: [product1.master, product2.master, product3.master, product6.master]) }
    let!(:completed_order_4) { create(:completed_order_with_totals, variants: [product2.master, product6.master]) }
    let!(:completed_order_5) { create(:completed_order_with_totals, variants: [product2.master, product6.master]) }
    let!(:completed_order_6) { create(:completed_order_with_totals, variants: [product6.master]) }

    before do
      visit spree.products_path
    end

    it 'can sort by best selling' do
      click_on 'sort-button'
      choose Spree.t('products_sort_options.best_selling'), allow_label_click: true
      wait_for_turbo

      within('.page-contents') do
        expect(page.all('.product-card-title').map(&:text)).to eq [
          product6.name,
          product2.name,
          product1.name,
          product3.name,
          product4.name
        ]
      end
    end

    it 'can sort alphabetically A-Z' do
      click_on 'sort-button'
      choose Spree.t('products_sort_options.name_a_z'), allow_label_click: true
      wait_for_turbo

      within('.page-contents') do
        expect(page.all('.product-card-title').map(&:text)).to eq [
          product6.name,
          product4.name,
          product1.name,
          product3.name,
          product2.name,
        ]
      end
    end

    it 'can sort alphabetically Z-A' do
      click_on 'sort-button'
      choose Spree.t('products_sort_options.name_z_a'), allow_label_click: true
      wait_for_turbo

      within('.page-contents') do
        expect(page.all('.product-card-title').map(&:text)).to eq [
          product2.name,
          product3.name,
          product1.name,
          product4.name,
          product6.name
        ]
      end
    end

    it 'can sort by price in ascending order' do
      click_on 'sort-button'
      choose Spree.t('products_sort_options.price_low_to_high'), allow_label_click: true
      wait_for_turbo

      within('.page-contents') do
        expect(page.all('.product-card-price p').map(&:text)).to eq ['$0.00', '$10.00', '$19.99', '$20.00', '$30.00']
      end
    end

    it 'can sort by price in descending order' do
      click_on 'sort-button'
      choose Spree.t('products_sort_options.price_high_to_low'), allow_label_click: true
      wait_for_turbo

      within('.page-contents') do
        expect(page.all('.product-card-price p').map(&:text)).to eq ['$30.00', '$20.00', '$19.99', '$10.00', '$0.00']
      end
    end

    it 'can sort by newest' do
      click_on 'sort-button'
      choose Spree.t('products_sort_options.newest_first'), allow_label_click: true
      wait_for_turbo

      within('.page-contents') do
        expect(page.all('.product-card-title').map(&:text)).to eq [
          product6.name,
          product4.name,
          product3.name,
          product2.name,
          product1.name,
        ]
      end
    end

    it 'can sort by oldest' do
      click_on 'sort-button'
      choose Spree.t('products_sort_options.oldest_first'), allow_label_click: true
      wait_for_turbo

      within('.page-contents') do
        expect(page.all('.product-card-title').map(&:text)).to eq [
          product1.name,
          product2.name,
          product3.name,
          product4.name,
          product6.name,
        ]
      end
    end
  end
end
