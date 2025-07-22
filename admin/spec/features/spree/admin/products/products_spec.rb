require 'spec_helper'

describe 'Products', type: :feature do
  let(:store) { Spree::Store.default }

  context 'as admin user' do
    stub_authorization!

    def build_option_type_with_values(name, values)
      ot = Spree::OptionType.find_by(name: name) || FactoryBot.create(:option_type, name: name)
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
      end

      context 'currency displaying' do
        context 'using Russian Rubles' do
          before do
            Spree::Store.default.update!(default_currency: 'RUB')
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

      context 'all products page' do
        let!(:active_product) { create(:product, status: 'active') }
        let!(:archived_product) { create(:product, status: 'archived') }

        it 'lists only non-archived products' do
          visit spree.admin_products_path
          expect(page).to have_content(active_product.name)
          expect(page).not_to have_content(archived_product.name)
        end
      end
    end

    context 'searching products' do
      it 'is able to search products by their properties' do
        create(:product, name: 'apache baseball cap', sku: 'A100')
        create(:product, name: 'zomg shirt')

        visit spree.admin_products_path
        fill_in 'q_multi_search', with: 'cap'
        within('main') { click_on 'Filter Results' }

        expect(page).to have_content('apache baseball cap')
        expect(page).not_to have_content('zomg shirt')
      end

      describe 'Products index tabs' do
        let!(:draft_product) { create(:product, status: 'draft') }
        let!(:pre_order_product) { create(:product, status: 'draft', available_on: 1.week.from_now) }
        let!(:active_product) { create(:product, status: 'active') }
        let!(:archived_product) { create(:product, status: 'archived') }
        let!(:deleted_product) { create(:product, status: 'archived', deleted_at: 1.day.ago) }

        before do
          visit spree.admin_products_path
        end

        context 'all products' do
          before do
            click_link 'All statuses'
          end

          it 'shows all the products without deleted' do
            expect(page).to have_content(draft_product.name)
            expect(page).to have_content(pre_order_product.name)
            expect(page).to have_content(active_product.name)
            expect(page).not_to have_content(archived_product.name)
            expect(page).not_to have_content(deleted_product.name)
          end
        end

        context 'active products' do
          before do
            click_link 'Active'
          end

          it 'shows all the active products without deleted' do
            expect(page).not_to have_content(draft_product.name)
            expect(page).not_to have_content(pre_order_product.name)
            expect(page).to have_content(active_product.name)
            expect(page).not_to have_content(archived_product.name)
            expect(page).not_to have_content(deleted_product.name)
          end
        end

        context 'draft products' do
          before do
            click_link 'Draft'
          end

          it 'shows all the draft products without deleted' do
            expect(page).to have_content(draft_product.name)
            expect(page).to have_content(pre_order_product.name)
            expect(page).not_to have_content(active_product.name)
            expect(page).not_to have_content(archived_product.name)
            expect(page).not_to have_content(deleted_product.name)
          end
        end

        context 'archived products' do
          before do
            click_link 'Archived'
          end

          it 'shows all the archived products without deleted' do
            expect(page).not_to have_content(draft_product.name)
            expect(page).not_to have_content(pre_order_product.name)
            expect(page).not_to have_content(active_product.name)
            expect(page).to have_content(archived_product.name)
            expect(page).not_to have_content(deleted_product.name)
          end
        end
      end
    end

    context 'updating a product' do
      let(:product) { create(:product, stores: Spree::Store.all) }

      let(:prototype) do
        size = build_option_type_with_values('size', %w(Small Medium Large))
        FactoryBot.create(:prototype, name: 'Size', option_types: [size])
      end

      before do
        @option_type_prototype = prototype
        @property_prototype = create(:prototype, name: 'Random')
      end

      it 'parses correctly available_on' do
        visit spree.edit_admin_product_path(product)
        fill_in 'product_available_on', with: '2012/12/25'
        within('#page-header') { click_button 'Update' }
        expect(page).to have_content('successfully updated!')
        expect(Spree::Product.last.available_on.to_date).to eq('2012-12-25'.to_date)
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
          visit spree.edit_admin_product_path(product)
          fill_in 'product_weight', with: '1'
          within('#page-header') { click_button 'Update' }
          weight_prev = find('#product_weight').value
          within('#page-header') { click_button 'Update' }
          expect(page).to have_field(id: 'product_weight', with: weight_prev)
        end
      end

      context 'changing the status' do
        context 'from draft' do
          before { product.update_column(:status, 'draft') }

          it 'to active' do
            change_status_and_update_record(to: 'Active')
          end
        end

        context 'from active' do
          it 'to draft' do
            change_status_and_update_record(to: 'Draft')
          end
        end

        context 'from archived' do
          before { product.update_column(:status, 'archived') }

          it 'to draft' do
            change_status_and_update_record(to: 'Draft')
          end

          it 'to active' do
            change_status_and_update_record(to: 'Active')
          end
        end

        def change_status_and_update_record(to:)
          visit spree.edit_admin_product_path(product)
          select to, from: 'product_status'
          within('#page-header') { click_button 'Update' }
          expect(page).to have_content('successfully updated')
          expect(product.reload.status).to eq(to.downcase.split(' ').join('_'))
        end
      end
    end

    describe 'product editing' do
      let(:product) { create(:product) }

      before do
        visit spree.edit_admin_product_path(product)
      end

      it 'correctly edits the product' do
        fill_in 'product_name', with: 'Test Product 123'
        fill_in 'product_description', with: 'This is a test product 123'
        fill_in 'product_master_attributes_prices_attributes_0_amount', with: 100
        fill_in 'product_master_attributes_prices_attributes_0_compare_at_amount', with: 200
        fill_in 'product_width', with: 10
        fill_in 'product_height', with: 10
        fill_in 'product_depth', with: 10
        fill_in 'product_weight', with: 10
        fill_in 'product_sku', with: '123456'
        fill_in 'product_barcode', with: '123456'
        fill_in 'product_master_attributes_stock_items_attributes_0_count_on_hand', with: 10
        within('#page-header') { click_button 'Update' }

        expect(page).to have_content('successfully updated')
        product.reload

        expect(product.name).to eq('Test Product 123')
        expect(product.description).to eq('This is a test product 123')
        expect(product.price_in('USD').amount).to eq(100)
        expect(product.price_in('USD').compare_at_amount).to eq(200)
        expect(product.width).to eq(10)
        expect(product.height).to eq(10)
        expect(product.depth).to eq(10)
        expect(product.weight).to eq(10)
        expect(product.sku).to eq('123456')
        expect(product.barcode).to eq('123456')
        expect(product.master.stock_items.first.count_on_hand).to eq(10)
      end
    end

    context 'filtering products', js: true do
      it 'renders selected filters' do
        visit spree.admin_products_path

        within 'main' do
          click_on 'Filters'
        end

        fill_in 'q_multi_search', with: 'Backpack'

        within('main') { click_on 'Filter Results' }

        within('.filter-badges-container') do
          expect(page).to have_content('Query: Backpack')
        end
      end

      context 'by tag' do
        let(:product_without_tag) { create(:product, stores: [store]) }
        let(:product) { create(:product, stores: [store]) }

        before do
          product.tag_list.add('some tag')
          product.save
        end

        it 'filters products with tag only' do
          visit spree.admin_products_path

          within('main') { click_on 'Filter' }
          fill_in 'Tags', with: 'some tag'

          find('.ts-dropdown').click
          find('#q_tags_name_in-ts-label').click
          click_on 'Filter Results'

          expect(page).to have_content(product.name)
          expect(page).not_to have_content(product_without_tag.name)
        end
      end
    end
  end
end
