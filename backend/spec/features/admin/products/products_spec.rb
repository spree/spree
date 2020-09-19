# coding: utf-8
require 'spec_helper'

describe 'Products', type: :feature do
  context 'as admin user' do
    stub_authorization!

    def build_option_type_with_values(name, values)
      ot = FactoryBot.create(:option_type, name: name)
      values.each do |val|
        ot.option_values.create(name: val.downcase, presentation: val)
      end
      ot
    end

    context 'listing products' do
      context 'sorting' do
        before do
          create(:product, name: 'apache baseball cap', price: 10)
          create(:product, name: 'zomg shirt', price: 5)
        end

        it 'lists existing products with correct sorting by name' do
          visit spree.admin_products_path
          # Name ASC
          within_row(1) { expect(page).to have_content('apache baseball cap') }
          within_row(2) { expect(page).to have_content('zomg shirt') }

          # Name DESC
          click_link 'admin_products_listing_name_title'
          within_row(1) { expect(page).to have_content('zomg shirt') }
          within_row(2) { expect(page).to have_content('apache baseball cap') }
        end

        it 'lists existing products with correct sorting by price' do
          visit spree.admin_products_path
          # Name ASC (default)
          within_row(1) { expect(page).to have_content('apache baseball cap') }
          within_row(2) { expect(page).to have_content('zomg shirt') }

          # Price DESC
          click_link 'admin_products_listing_price_title'
          within_row(1) { expect(page).to have_content('zomg shirt') }
          within_row(2) { expect(page).to have_content('apache baseball cap') }
        end
      end

      context 'currency displaying' do
        context 'using Russian Rubles' do
          before do
            Spree::Config[:currency] = 'RUB'
            create(:store, default: true, default_currency: 'RUB')
            create(:product, name: 'Just a product', price: 19.99)
          end

          # Regression test for #2737
          context 'uses руб as the currency symbol' do
            it 'on the products listing page' do
              visit spree.admin_products_path
              within_row(1) { expect(page).to have_content('19.99 ₽') }
            end
          end
        end
      end
    end

    context 'searching products' do
      it 'is able to search deleted products' do
        create(:product, name: 'apache baseball cap', deleted_at: '2011-01-06 18:21:13')
        create(:product, name: 'zomg shirt')

        visit spree.admin_products_path
        expect(page).to have_content('zomg shirt')
        expect(page).not_to have_content('apache baseball cap')

        check 'Show Deleted'
        click_on 'Search'

        expect(page).to have_content('zomg shirt')
        expect(page).to have_content('apache baseball cap')

        uncheck 'Show Deleted'
        click_on 'Search'

        expect(page).to have_content('zomg shirt')
        expect(page).not_to have_content('apache baseball cap')
      end

      it 'is able to search products by their properties' do
        create(:product, name: 'apache baseball cap', sku: 'A100')
        create(:product, name: 'apache baseball cap2', sku: 'B100')
        create(:product, name: 'zomg shirt')

        visit spree.admin_products_path
        fill_in 'q_search_by_name', with: 'ap'
        click_on 'Search'

        expect(page).to have_content('apache baseball cap')
        expect(page).to have_content('apache baseball cap2')
        expect(page).not_to have_content('zomg shirt')

        fill_in 'q_variants_including_master_sku_cont', with: 'A1'
        click_on 'Search'

        expect(page).to have_content('apache baseball cap')
        expect(page).not_to have_content('apache baseball cap2')
        expect(page).not_to have_content('zomg shirt')
      end
    end

    context 'creating a new product from a prototype', js: true do
      def build_option_type_with_values(name, values)
        ot = FactoryBot.create(:option_type, name: name)
        values.each do |val|
          ot.option_values.create(name: val.downcase, presentation: val)
        end
        ot
      end

      let(:product_attributes) do
        # FactoryBot.attributes_for is un-deprecated!
        #   https://github.com/thoughtbot/factory_bot/issues/274#issuecomment-3592054
        FactoryBot.attributes_for(:simple_product)
      end

      let(:prototype) do
        size = build_option_type_with_values('size', %w(Small Medium Large))
        FactoryBot.create(:prototype, name: 'Size', option_types: [size])
      end

      let(:option_values_hash) do
        hash = {}
        prototype.option_types.each do |i|
          hash[i.id.to_s] = i.option_value_ids
        end
        hash
      end

      before do
        @option_type_prototype = prototype
        @property_prototype = create(:prototype, name: 'Random')
        @shipping_category = create(:shipping_category)
        visit spree.admin_products_path
        within find('#contentHeader') do
          click_link 'admin_new_product'
        end
        within('#new_product') do
          expect(page).to have_content('SKU')
        end
      end

      it 'allows an admin to create a new product and variants from a prototype' do
        fill_in 'product_name', with: 'Baseball Cap'
        fill_in 'product_sku', with: 'B100'
        fill_in 'product_price', with: '100'
        fill_in 'product_available_on', with: '2012/01/24'
        find('#product_available_on').send_keys(:tab)
        select2 'Size', from: 'Prototype'
        check 'Large'
        select2 @shipping_category.name, css: '#product_shipping_category_field'
        click_button 'Create'
        expect(page).to have_content('successfully created!')
        expect(Spree::Product.last.variants.length).to eq(1)
      end

      it 'does not display variants when prototype does not contain option types' do
        select2 'Random', from: 'Prototype'

        fill_in 'product_name', with: 'Baseball Cap'

        expect(page).not_to have_content('Variants')
      end

      context 'with html5 validations' do
        it 'keeps option values selected if validation fails' do
          fill_in 'product_name', with: 'Baseball Cap'
          fill_in 'product_sku', with: 'B100'
          fill_in 'product_price', with: '100'
          select2 'Size', from: 'Prototype'
          check 'Large'
          click_button 'Create'

          expect(page).to have_css('#product_shipping_category_field') do |el|
            el['validationMessage'] == 'Please select an item in the list.'
          end
          expect(page).to have_checked_field('Size')
          expect(page).to have_checked_field('Large')
          expect(page).to have_unchecked_field('Small')
        end
      end

      context 'without html5 validations' do
        it 'keeps option values selected if validation fails' do
          disable_html5_validation
          fill_in 'product_name', with: 'Baseball Cap'
          fill_in 'product_sku', with: 'B100'
          fill_in 'product_price', with: '100'
          select2 'Size', from: 'Prototype'
          check 'Large'
          click_button 'Create'
          expect(page).to have_content("Shipping Category can't be blank")
          expect(page).to have_checked_field('Size')
          expect(page).to have_checked_field('Large')
          expect(page).to have_unchecked_field('Small')
        end
      end
    end

    context 'creating a new product' do
      before do
        @shipping_category = create(:shipping_category)
        visit spree.admin_products_path
        within find('#contentHeader') do
          click_link 'admin_new_product'
        end

        within('#new_product') do
          expect(page).to have_content('SKU')
        end
      end

      it 'allows an admin to create a new product' do
        fill_in 'product_name', with: 'Baseball Cap'
        fill_in 'product_sku', with: 'B100'
        fill_in 'product_price', with: '100'
        fill_in 'product_available_on', with: '2012/01/24'
        select @shipping_category.name, from: 'product_shipping_category_id'
        click_button 'Create'
        expect(page).to have_content('successfully created!')
        click_button 'Update'
        expect(page).to have_content('successfully updated!')
      end

      it 'shows validation errors' do
        fill_in 'product_name', with: 'Baseball Cap'
        fill_in 'product_sku', with: 'B100'
        fill_in 'product_price', with: '100'
        click_button 'Create'
        expect(page).to have_content("Shipping Category can't be blank")
      end

      context 'using a locale with a different decimal format ' do
        before do
          # change English locale's separator and delimiter to match 19,99 format
          I18n.backend.store_translations(:en,
                                          number: {
                                            currency: {
                                              format: {
                                                separator: ',',
                                                delimiter: '.'
                                              }
                                            }
                                          })
        end

        after do
          # revert changes to English locale
          I18n.backend.store_translations(:en,
                                          number: {
                                            currency: {
                                              format: {
                                                separator: '.',
                                                delimiter: ','
                                              }
                                            }
                                          })
        end

        it 'shows localized price value on validation errors', js: true do
          fill_in 'product_price', with: '19,99'
          click_button 'Create'
          expect(page).to have_field(id: 'product_price', with: '19,99')
        end
      end

      # Regression test for #2097
      it 'can set the count on hand to a null value' do
        fill_in 'product_name', with: 'Baseball Cap'
        fill_in 'product_price', with: '100'
        select @shipping_category.name, from: 'product_shipping_category_id'
        click_button 'Create'
        expect(page).to have_content('successfully created!')
        click_button 'Update'
        expect(page).to have_content('successfully updated!')
      end
    end

    context 'cloning a product', js: true do
      it 'allows an admin to clone a product' do
        create(:product)

        visit spree.admin_products_path
        within_row(1) do
          click_icon :clone
        end

        expect(page).to have_content('Product has been cloned')
      end

      context 'cloning a deleted product' do
        it 'allows an admin to clone a deleted product' do
          create(:product, name: 'apache baseball cap')

          visit spree.admin_products_path
          click_on 'Filter'
          check 'Show Deleted'
          click_on 'Search'

          expect(page).to have_content('apache baseball cap')

          within_row(1) do
            click_icon :clone
          end

          expect(page).to have_content('Product has been cloned')
        end
      end
    end

    context 'updating a product' do
      let(:product) { create(:product) }

      let(:prototype) do
        size = build_option_type_with_values('size', %w(Small Medium Large))
        FactoryBot.create(:prototype, name: 'Size', option_types: [size])
      end

      before do
        @option_type_prototype = prototype
        @property_prototype = create(:prototype, name: 'Random')
      end

      it 'parses correctly available_on' do
        visit spree.admin_product_path(product)
        fill_in 'product_available_on', with: '2012/12/25'
        click_button 'Update'
        expect(page).to have_content('successfully updated!')
        expect(Spree::Product.last.available_on.to_s).to eq('2012-12-25 00:00:00 UTC')
      end

      it 'adds option_types when selecting a prototype', js: true do
        visit spree.admin_product_path(product)
        within('#sidebar') do
          click_link 'Properties'
        end
        click_link 'Select From Prototype'

        within("#prototypes tr#row_#{prototype.id}") do
          click_link 'Select'
        end

        within(:css, 'tr.product_property:first-child') do
          expect(page).to have_field(id: /property_name$/, with: 'baseball_cap_color')
        end
      end

      context 'using a locale with a different decimal format' do
        before do
          # change English locale's separator and delimiter to match 19,99 format
          I18n.backend.store_translations(
            :en,
            number: {
              currency: {
                format: {
                  separator: ',',
                  delimiter: '.'
                }
              },
              format: {
                separator: ',',
                delimiter: '.'
              }
            }
          )
        end

        after do
          # revert changes to English locale
          I18n.backend.store_translations(
            :en,
            number: {
              currency: {
                format: {
                  separator: '.',
                  delimiter: ','
                }
              },
              format: {
                separator: '.',
                delimiter: ','
              }
            }
          )
        end

        it 'parses correctly decimal values like weight' do
          visit spree.admin_product_path(product)
          fill_in 'product_weight', with: '1'
          click_button 'Update'
          weight_prev = find('#product_weight').value
          click_button 'Update'
          expect(page).to have_field(id: 'product_weight', with: weight_prev)
        end
      end
    end

    context 'deleting a product', js: true do
      let!(:product) { create(:product) }

      it 'is still viewable' do
        visit spree.admin_products_path
        accept_confirm do
          click_icon :delete
        end
        expect(page).to have_content('Product has been deleted')

        click_on 'Filter'
        # This will show our deleted product
        check 'Show Deleted'
        click_on 'Search'
        click_link(product.name, match: :first)
        expect(page).to have_field(id: 'product_price') do |field|
          field.value.to_f == product.price.to_f
        end
      end
    end

    context 'filtering products', js: true do
      it 'renders selected filters' do
        visit spree.admin_products_path

        click_on 'Filter'

        within('#table-filter') do
          fill_in 'q_search_by_name', with: 'Backpack'
          fill_in 'q_variants_including_master_sku_cont', with: 'BAG-00001'
        end

        click_on 'Search'

        within('.table-active-filters') do
          expect(page).to have_content('Name: Backpack')
          expect(page).to have_content('SKU: BAG-00001')
        end
      end
    end

    context 'editing product compare at price', js: true do
      let!(:product) { create(:product) }

      it 'lets admin edit compare at price for product' do
        visit spree.admin_products_path
        within_row(1) { click_icon :edit }

        fill_in 'product_compare_at_price', with: '99.99'
        click_button 'Update'

        expect(page).to have_content 'successfully updated!'
      end
    end
  end

  context 'with only product permissions' do
    before do
      allow_any_instance_of(Spree::Admin::BaseController).to receive(:spree_current_user).and_return(nil)
    end

    custom_authorization! do |_user|
      can [:admin, :update, :read], Spree::Product
    end
    let!(:product) { create(:product) }

    it 'only displays accessible links on index' do
      visit spree.admin_products_path

      expect(page).to have_link('Products')
      expect(page).not_to have_link('Option Types')
      expect(page).not_to have_link('Properties')
      expect(page).not_to have_link('Prototypes')
      expect(page).not_to have_link('New Product')
      expect(page).not_to have_css('.icon-clone')
      expect(page).to have_css('.icon-edit')
      expect(page).not_to have_css('.delete-resource')
    end

    it 'only displays accessible links on edit' do
      visit spree.admin_product_path(product)

      # product tabs should be hidden
      expect(page).to have_link('Details')
      expect(page).not_to have_link('Images')
      expect(page).not_to have_link('Variants')
      expect(page).not_to have_link('Properties')
      expect(page).not_to have_link('Stock Management')

      # no create permission
      expect(page).not_to have_link('New Product')
    end
  end
end
