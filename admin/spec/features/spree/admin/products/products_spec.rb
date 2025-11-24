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

    def select_option_value(option_value_name, index: 0, create: false)
      select_element = all('[data-multi-tom-select-target="select"]')[index]

      within(select_element) do
        tom_select(option_value_name, from: 'new_option_values_-ts-control', create: create)
      end
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

      it 'allows adding new options', js: true do
        # Add the first option - Color
        find('span', text: Spree.t('admin.variants_form.add_option.empty')).click
        tom_select('Color', from: Spree.t(:option_name), create: true)
        select_option_value('Black', index: 0, create: true)
        select_option_value('White', index: 1, create: true)
        click_on 'Done'

        within('#option-Color') do
          expect(page).to have_content('Black')
          expect(page).to have_content('White')
        end

        # Add the second option - Size
        find('span', text: Spree.t('admin.variants_form.add_option.not_empty')).click
        tom_select('Size', from: Spree.t(:option_name), create: true)
        select_option_value('Small', index: 0, create: true)
        select_option_value('Medium', index: 1, create: true)
        select_option_value('Large', index: 2, create: true)
        click_on 'Done'

        within('#option-Size') do
          expect(page).to have_content('Small')
          expect(page).to have_content('Medium')
          expect(page).to have_content('Large')
        end

        within('[data-test-id="product-variants-table"]') do
          within('[data-variant-name="Black/Small"]') do
            within('.column-price') { find('input').set(10) }
            within('.column-quantity') { find('input').set(100) }
          end

          within('[data-variant-name="Black/Medium"]') do
            within('.column-price') { find('input').set(11) }
            within('.column-quantity') { find('input').set(110) }
          end

          within('[data-variant-name="Black/Large"]') do
            within('.column-price') { find('input').set(12) }
            within('.column-quantity') { find('input').set(120) }
          end

          within('[data-variant-name="White/Small"]') do
            within('.column-price') { find('input').set(20) }
            within('.column-quantity') { find('input').set(200) }
          end

          within('[data-variant-name="White/Medium"]') do
            within('.column-price') { find('input').set(21) }
            within('.column-quantity') { find('input').set(210) }
          end

          within('[data-variant-name="White/Large"]') do
            within('.column-price') { find('input').set(22) }
            within('.column-quantity') { find('input').set(220) }
          end
        end

        # Update product variants
        click_on 'Update', match: :first
        expect(page).to have_content('successfully updated')

        color_option = Spree::OptionType.find_by(name: 'color')
        size_option = Spree::OptionType.find_by(name: 'size')

        within("#option-#{color_option.id}") do
          expect(page).to have_content('Black')
          expect(page).to have_content('White')
        end

        within("#option-#{size_option.id}") do
          expect(page).to have_content('Small')
          expect(page).to have_content('Medium')
          expect(page).to have_content('Large')
        end

        within('[data-test-id="product-variants-table"]') do
          within('[data-variant-name="Black/Small"]') do
            within('.column-price') { expect(page).to have_field(with: 10) }
            within('.column-quantity') { expect(page).to have_field(with: 100) }
          end

          within('[data-variant-name="Black/Medium"]') do
            within('.column-price') { expect(page).to have_field(with: 11) }
            within('.column-quantity') { expect(page).to have_field(with: 110) }
          end

          within('[data-variant-name="Black/Large"]') do
            within('.column-price') { expect(page).to have_field(with: 12) }
            within('.column-quantity') { expect(page).to have_field(with: 120) }
          end

          within('[data-variant-name="White/Small"]') do
            within('.column-price') { expect(page).to have_field(with: 20) }
            within('.column-quantity') { expect(page).to have_field(with: 200) }
          end

          within('[data-variant-name="White/Medium"]') do
            within('.column-price') { expect(page).to have_field(with: 21) }
            within('.column-quantity') { expect(page).to have_field(with: 210) }
          end

          within('[data-variant-name="White/Large"]') do
            within('.column-price') { expect(page).to have_field(with: 22) }
            within('.column-quantity') { expect(page).to have_field(with: 220) }
          end
        end

        expected_variant_options_text = [
          'Color: Black, Size: Small',
          'Color: Black, Size: Medium',
          'Color: Black, Size: Large',
          'Color: White, Size: Small',
          'Color: White, Size: Medium',
          'Color: White, Size: Large'
        ]

        expect(product.reload.variants.map(&:options_text)).to eq(expected_variant_options_text)

        # Update product variants to check if the order is preserved
        click_on 'Update', match: :first
        expect(page).to have_content('successfully updated')

        expect(product.reload.variants.map(&:options_text)).to eq(expected_variant_options_text)
      end

      it 'allows adding new option values', js: true do
        # Add the first option - Color
        find('span', text: Spree.t('admin.variants_form.add_option.empty')).click
        tom_select('Color', from: Spree.t(:option_name), create: true)
        select_option_value('Black', index: 0, create: true)
        select_option_value('White', index: 1, create: true)
        click_on 'Done'

        within('#option-Color') do
          expect(page).to have_content('Black')
          expect(page).to have_content('White')
        end

        # Update product variants
        click_on 'Update', match: :first
        expect(page).to have_content('successfully updated')
        within('.alerts-container') { find('button').click }

        color_option = Spree::OptionType.find_by(name: 'color')

        within("#option-#{color_option.id}") do
          click_on 'Edit'
          select_option_value('Red', index: 2, create: true)
          click_on 'Done'
        end

        within("#option-#{color_option.id}") do
          expect(page).to have_content('Black')
          expect(page).to have_content('White')
          expect(page).to have_content('Red')
        end

        # Update product variants
        click_on 'Update', match: :first
        expect(page).to have_content('successfully updated')
        within('.alerts-container') { find('button').click }

        within('[data-test-id="product-variants-table"]') do
          expect(page).to have_content('Black')
          expect(page).to have_content('White')
          expect(page).to have_content('Red')
        end

        expect(product.reload.variants.map(&:options_text)).to contain_exactly(
          'Color: Black',
          'Color: White',
          'Color: Red'
        )
      end

      it 'uses the parent stock level for new variants', js: true do
        # Add the first option - Color
        find('span', text: Spree.t('admin.variants_form.add_option.empty')).click
        tom_select('Color', from: Spree.t(:option_name), create: true)
        select_option_value('Black', index: 0, create: true)
        select_option_value('White', index: 1, create: true)
        click_on 'Done'

        within('#option-Color') do
          expect(page).to have_content('Black')
          expect(page).to have_content('White')
        end

        # Set stock levels for the color variants
        within('[data-test-id="product-variants-table"]') do
          within('[data-variant-name="Black"]') do
            within('.column-quantity') { find('input').set(100) }
          end

          within('[data-variant-name="White"]') do
            within('.column-quantity') { find('input').set(200) }
          end
        end

        # Update product variants
        click_on 'Update', match: :first
        expect(page).to have_content('successfully updated')
        within('.alerts-container') { find('button').click }

        # Add the second option - Size
        find('span', text: Spree.t('admin.variants_form.add_option.not_empty')).click
        tom_select('Size', from: Spree.t(:option_name), create: true)
        select_option_value('Small', index: 0, create: true)
        select_option_value('Medium', index: 1, create: true)
        select_option_value('Large', index: 2, create: true)
        click_on 'Done'

        within('#option-Size') do
          expect(page).to have_content('Small')
          expect(page).to have_content('Medium')
          expect(page).to have_content('Large')
        end

        # Check stock levels for the color/size variants
        within('[data-test-id="product-variants-table"]') do
          within('[data-variant-name="Black"]') do
            within('.column-quantity') { expect(page).to have_field(placeholder: 300) }
          end

          within('[data-variant-name="Black/Small"]') do
            within('.column-quantity') { expect(page).to have_field(with: 100) }
          end

          within('[data-variant-name="Black/Medium"]') do
            within('.column-quantity') { expect(page).to have_field(with: 100) }
          end

          within('[data-variant-name="Black/Large"]') do
            within('.column-quantity') { expect(page).to have_field(with: 100) }
          end

          within('[data-variant-name="White"]') do
            within('.column-quantity') { expect(page).to have_field(placeholder: 600) }
          end

          within('[data-variant-name="White/Small"]') do
            within('.column-quantity') { expect(page).to have_field(with: 200) }
          end

          within('[data-variant-name="White/Medium"]') do
            within('.column-quantity') { expect(page).to have_field(with: 200) }
          end

          within('[data-variant-name="White/Large"]') do
            within('.column-quantity') { expect(page).to have_field(with: 200) }
          end
        end

        # Update product variants
        click_on 'Update', match: :first
        expect(page).to have_content('successfully updated')
        within('.alerts-container') { find('button').click }

        # Make sure the stock levels are still correct after the update
        within('[data-test-id="product-variants-table"]') do
          within('[data-variant-name="Black"]') do
            within('.column-quantity') { expect(page).to have_field(placeholder: 300) }
          end

          within('[data-variant-name="Black/Small"]') do
            within('.column-quantity') { expect(page).to have_field(with: 100) }
          end

          within('[data-variant-name="Black/Medium"]') do
            within('.column-quantity') { expect(page).to have_field(with: 100) }
          end

          within('[data-variant-name="Black/Large"]') do
            within('.column-quantity') { expect(page).to have_field(with: 100) }
          end

          within('[data-variant-name="White"]') do
            within('.column-quantity') { expect(page).to have_field(placeholder: 600) }
          end

          within('[data-variant-name="White/Small"]') do
            within('.column-quantity') { expect(page).to have_field(with: 200) }
          end

          within('[data-variant-name="White/Medium"]') do
            within('.column-quantity') { expect(page).to have_field(with: 200) }
          end

          within('[data-variant-name="White/Large"]') do
            within('.column-quantity') { expect(page).to have_field(with: 200) }
          end
        end
      end

      context 'for a product with existing options', js: true do
        let!(:color_option) { create(:option_type, name: 'color', presentation: 'Color', products: [product]) }
        let!(:black_option_value) { create(:option_value, name: 'black', presentation: 'Black', option_type: color_option) }
        let!(:white_option_value) { create(:option_value, name: 'white', presentation: 'White', option_type: color_option) }

        let!(:size_option) { create(:option_type, name: 'size', presentation: 'Size', products: [product]) }
        let!(:small_option_value) { create(:option_value, name: 'small', presentation: 'Small', option_type: size_option) }
        let!(:medium_option_value) { create(:option_value, name: 'medium', presentation: 'Medium', option_type: size_option) }
        let!(:large_option_value) { create(:option_value, name: 'large', presentation: 'Large', option_type: size_option) }

        let!(:variant1) { create(:variant, product: product, option_values: [black_option_value, small_option_value], price: 10) }
        let!(:variant2) { create(:variant, product: product, option_values: [black_option_value, medium_option_value], price: 10) }
        let!(:variant3) { create(:variant, product: product, option_values: [black_option_value, large_option_value], price: 10) }

        let!(:variant4) { create(:variant, product: product, option_values: [white_option_value, small_option_value], price: 11) }
        let!(:variant5) { create(:variant, product: product, option_values: [white_option_value, medium_option_value], price: 11) }
        let!(:variant6) { create(:variant, product: product, option_values: [white_option_value, large_option_value], price: 11) }

        it 'allows adding another option' do
          visit spree.edit_admin_product_path(product.reload)

          find('span', text: Spree.t('admin.variants_form.add_option.not_empty')).click
          tom_select('Material', from: Spree.t(:option_name), create: true)
          select_option_value('Cotton', index: 0, create: true)
          select_option_value('Polyester', index: 1, create: true)
          click_on 'Done'

          within('#option-Material') do
            expect(page).to have_content('Cotton')
            expect(page).to have_content('Polyester')
          end

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Black/Small/Cotton"]') do
              within('.column-price') { find('input').set(10) }
              within('.column-quantity') { find('input').set(100) }
            end

            within('[data-variant-name="Black/Small/Polyester"]') do
              within('.column-price') { find('input').set(11) }
              within('.column-quantity') { find('input').set(110) }
            end

            within('[data-variant-name="Black/Medium/Cotton"]') do
              within('.column-price') { find('input').set(12) }
              within('.column-quantity') { find('input').set(120) }
            end

            within('[data-variant-name="Black/Medium/Polyester"]') do
              within('.column-price') { find('input').set(13) }
              within('.column-quantity') { find('input').set(130) }
            end

            within('[data-variant-name="Black/Large/Cotton"]') do
              within('.column-price') { find('input').set(14) }
              within('.column-quantity') { find('input').set(140) }
            end

            within('[data-variant-name="Black/Large/Polyester"]') do
              within('.column-price') { find('input').set(15) }
              within('.column-quantity') { find('input').set(150) }
            end

            within('[data-variant-name="White"]') do
              within('.column-price') { find('input').set(20) }
              within('.column-quantity') { find('input').set(200) }
            end
          end

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')

          material_option = Spree::OptionType.find_by(name: 'material')

          within("#option-#{material_option.id}") do
            expect(page).to have_content('Cotton')
            expect(page).to have_content('Polyester')
          end

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Black/Small/Cotton"]') do
              within('.column-price') { find('input').set(10) }
              within('.column-quantity') { find('input').set(100) }
            end

            within('[data-variant-name="Black/Small/Polyester"]') do
              within('.column-price') { find('input').set(11) }
              within('.column-quantity') { find('input').set(110) }
            end

            within('[data-variant-name="Black/Medium/Cotton"]') do
              within('.column-price') { find('input').set(12) }
              within('.column-quantity') { find('input').set(120) }
            end

            within('[data-variant-name="Black/Medium/Polyester"]') do
              within('.column-price') { find('input').set(13) }
              within('.column-quantity') { find('input').set(130) }
            end

            within('[data-variant-name="Black/Large/Cotton"]') do
              within('.column-price') { find('input').set(14) }
              within('.column-quantity') { find('input').set(140) }
            end

            within('[data-variant-name="Black/Large/Polyester"]') do
              within('.column-price') { find('input').set(15) }
              within('.column-quantity') { find('input').set(150) }
            end

            within('[data-variant-name="White/Small/Cotton"]') do
              within('.column-price') { find('input').set(20) }
              within('.column-quantity') { find('input').set(200) }
            end

            within('[data-variant-name="White/Small/Polyester"]') do
              within('.column-price') { find('input').set(20) }
              within('.column-quantity') { find('input').set(200) }
            end

            within('[data-variant-name="White/Medium/Cotton"]') do
              within('.column-price') { find('input').set(20) }
              within('.column-quantity') { find('input').set(200) }
            end

            within('[data-variant-name="White/Medium/Polyester"]') do
              within('.column-price') { find('input').set(20) }
              within('.column-quantity') { find('input').set(200) }
            end

            within('[data-variant-name="White/Large/Cotton"]') do
              within('.column-price') { find('input').set(20) }
              within('.column-quantity') { find('input').set(200) }
            end

            within('[data-variant-name="White/Large/Polyester"]') do
              within('.column-price') { find('input').set(20) }
              within('.column-quantity') { find('input').set(200) }
            end
          end

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Color: Black, Size: Small, and Material: Cotton',
            'Color: Black, Size: Small, and Material: Polyester',
            'Color: Black, Size: Medium, and Material: Cotton',
            'Color: Black, Size: Medium, and Material: Polyester',
            'Color: Black, Size: Large, and Material: Cotton',
            'Color: Black, Size: Large, and Material: Polyester',
            'Color: White, Size: Small, and Material: Cotton',
            'Color: White, Size: Small, and Material: Polyester',
            'Color: White, Size: Medium, and Material: Cotton',
            'Color: White, Size: Medium, and Material: Polyester',
            'Color: White, Size: Large, and Material: Cotton',
            'Color: White, Size: Large, and Material: Polyester'
          )
        end

        it 'allows removing the first option' do
          visit spree.edit_admin_product_path(product.reload)

          within("#option-#{color_option.id}") do
            click_on 'Edit'
            click_on 'Delete'
          end

          expect(page).not_to have_css("#option-#{color_option.id}")
          expect(page).to have_css("#option-#{size_option.id}")

          within('[data-test-id="product-variants-table"]') do
            expect(page).not_to have_content('Black')
            expect(page).not_to have_content('White')

            expect(page).to have_content('Small')
            expect(page).to have_content('Medium')
            expect(page).to have_content('Large')

            within('[data-variant-name="Small"]') do
              within('.column-price') { find('input').set(10) }
              within('.column-quantity') { find('input').set(100) }
            end

            within('[data-variant-name="Medium"]') do
              within('.column-price') { find('input').set(11) }
              within('.column-quantity') { find('input').set(110) }
            end

            within('[data-variant-name="Large"]') do
              within('.column-price') { find('input').set(12) }
              within('.column-quantity') { find('input').set(120) }
            end
          end

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')
          within('.alerts-container') { find('button').click }

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Small"]') do
              within('.column-price') { expect(page).to have_field(with: 10) }
              within('.column-quantity') { expect(page).to have_field(with: 100) }
            end

            within('[data-variant-name="Medium"]') do
              within('.column-price') { expect(page).to have_field(with: 11) }
              within('.column-quantity') { expect(page).to have_field(with: 110) }
            end

            within('[data-variant-name="Large"]') do
              within('.column-price') { expect(page).to have_field(with: 12) }
              within('.column-quantity') { expect(page).to have_field(with: 120) }
            end
          end

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Size: Small',
            'Size: Medium',
            'Size: Large'
          )

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Small"]') do
              find('.column-checkbox').click
            end
          end

          click_on 'Delete selected'

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')
          within('.alerts-container') { find('button').click }

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Medium"]') do
              within('.column-price') { expect(page).to have_field(with: 11) }
              within('.column-quantity') { expect(page).to have_field(with: 110) }
            end

            within('[data-variant-name="Large"]') do
              within('.column-price') { expect(page).to have_field(with: 12) }
              within('.column-quantity') { expect(page).to have_field(with: 120) }
            end
          end

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Size: Medium',
            'Size: Large'
          )
        end

        it 'allows removing the last option' do
          visit spree.edit_admin_product_path(product.reload)

          within("#option-#{size_option.id}") do
            click_on 'Edit'
            click_on 'Delete'
          end

          expect(page).to have_css("#option-#{color_option.id}")
          expect(page).not_to have_css("#option-#{size_option.id}")

          within('[data-test-id="product-variants-table"]') do
            expect(page).to have_content('Black')
            expect(page).to have_content('White')

            expect(page).not_to have_content('Small')
            expect(page).not_to have_content('Medium')
            expect(page).not_to have_content('Large')
          end

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')

          within('[data-test-id="product-variants-table"]') do
            expect(page).to have_content('Black')
            expect(page).to have_content('White')

            expect(page).not_to have_content('Small')
            expect(page).not_to have_content('Medium')
            expect(page).not_to have_content('Large')
          end

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Color: Black',
            'Color: White'
          )
        end

        it 'allows removing all options' do
          visit spree.edit_admin_product_path(product.reload)

          within("#option-#{color_option.id}") do
            click_on 'Edit'
            click_on 'Delete'
          end

          within("#option-#{size_option.id}") do
            click_on 'Edit'
            click_on 'Delete'
          end

          expect(page).not_to have_css("#option-#{color_option.id}")
          expect(page).not_to have_css("#option-#{size_option.id}")
          expect(page).not_to have_css('[data-test-id="product-variants-table"]')

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')

          within('.variants-form') { expect(page).to have_content(Spree.t('admin.variants_form.add_option.empty')) }
          expect(product.reload.variants).to be_empty
        end

        it 'allows removing all options and adding one back and a new one' do
          visit spree.edit_admin_product_path(product.reload)

          within("#option-#{color_option.id}") do
            click_on 'Edit'
            click_on 'Delete'
          end

          within("#option-#{size_option.id}") do
            click_on 'Edit'
            click_on 'Delete'
          end

          # Add color back
          find('span', text: Spree.t('admin.variants_form.add_option.empty')).click
          tom_select('Color', from: Spree.t(:option_name))
          select_option_value('White', index: 0)
          click_on 'Done'

          within("#option-#{color_option.id}") do
            expect(page).to have_content('White')
          end

          # Add a new material option
          find('span', text: Spree.t('admin.variants_form.add_option.not_empty')).click
          tom_select('Material', from: Spree.t(:option_name), create: true)
          select_option_value('Cotton', index: 0, create: true)
          select_option_value('Polyester', index: 1, create: true)
          click_on 'Done'

          within('#option-Material') do
            expect(page).to have_content('Cotton')
            expect(page).to have_content('Polyester')
          end

          within('[data-test-id="product-variants-table"]') do
            expect(page).not_to have_content('Black')
            expect(page).not_to have_content('Small')
            expect(page).not_to have_content('Medium')
            expect(page).not_to have_content('Large')

            expect(page).to have_content('White')
            expect(page).to have_content('Cotton')
            expect(page).to have_content('Polyester')

            within('[data-variant-name="White/Cotton"]') do
              within('.column-price') { find('input').set(20) }
              within('.column-quantity') { find('input').set(200) }
            end

            within('[data-variant-name="White/Polyester"]') do
              within('.column-price') { find('input').set(21) }
              within('.column-quantity') { find('input').set(210) }
            end
          end

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="White/Cotton"]') do
              within('.column-price') { expect(page).to have_field(with: 20) }
              within('.column-quantity') { expect(page).to have_field(with: 200) }
            end

            within('[data-variant-name="White/Polyester"]') do
              within('.column-price') { expect(page).to have_field(with: 21) }
              within('.column-quantity') { expect(page).to have_field(with: 210) }
            end
          end

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Color: White, Material: Cotton',
            'Color: White, Material: Polyester'
          )
        end

        it 'allows removing selected variants' do
          red_option_value = create(:option_value, name: 'red', presentation: 'Red', option_type: color_option)
          create(:variant, product: product, option_values: [red_option_value, small_option_value], price: 10)
          create(:variant, product: product, option_values: [red_option_value, medium_option_value], price: 10)
          create(:variant, product: product, option_values: [red_option_value, large_option_value], price: 10)

          visit spree.edit_admin_product_path(product.reload)

          # Remove Red color entirely and Black/Medium variant
          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Red"]') do
              find('.column-checkbox').click
            end
          end

          click_on 'Delete selected'

          within("#option-#{color_option.id}") do
            expect(page).not_to have_content('Red')
            expect(page).to have_content('Black')
            expect(page).to have_content('White')
          end

          within('[data-test-id="product-variants-table"]') do
            expect(page).not_to have_content('Red')
            expect(page).to have_content('Black')
            expect(page).to have_content('White')
          end

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Black/Medium"]') do
              find('.column-checkbox').click
            end
          end

          click_on 'Delete selected'

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')
          within('.alerts-container') { find('button').click }

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Color: Black, Size: Small',
            'Color: Black, Size: Large',
            'Color: White, Size: Small',
            'Color: White, Size: Medium',
            'Color: White, Size: Large'
          )

          # Remove White/Small and White/Large variants
          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="White/Small"]') do
              find('.column-checkbox').click
            end

            within('[data-variant-name="White/Large"]') do
              find('.column-checkbox').click
            end
          end

          click_on 'Delete selected'

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')
          within('.alerts-container') { find('button').click }

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Color: Black, Size: Small',
            'Color: Black, Size: Large',
            'Color: White, Size: Medium'
          )

          # Remove the last White/Medium variant and then Black/Medium and Black/Large variants
          within('[data-test-id="product-variants-table"]') do
            expect(page).to have_css('[data-variant-name="White"]')
            expect(page).to have_css('[data-variant-name="White/Medium"]')

            expect(page).not_to have_css('[data-variant-name="White/Small"]')
            expect(page).not_to have_css('[data-variant-name="White/Large"]')

            within('[data-variant-name="White/Medium"]') do
              find('.column-checkbox').click
            end
          end

          click_on 'Delete selected'

          within("#option-#{color_option.id}") do
            expect(page).not_to have_content('White')
            expect(page).to have_content('Black')
          end

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Black/Medium"]') do
              find('.column-checkbox').click
            end

            within('[data-variant-name="Black/Large"]') do
              find('.column-checkbox').click
            end
          end

          click_on 'Delete selected'

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')
          within('.alerts-container') { find('button').click }

          within("#option-#{color_option.id}") do
            expect(page).to have_content('Black')
            expect(page).not_to have_content('White')
          end

          within("#option-#{size_option.id}") do
            expect(page).to have_content('Small')
            expect(page).not_to have_content('Medium')
            expect(page).not_to have_content('Large')
          end

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Color: Black, Size: Small'
          )
        end

        it 'uses the parent price for new variants' do
          visit spree.edit_admin_product_path(product.reload)

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Black"]') do
              within('.column-price') { expect(page).to have_field(with: 10) }
            end

            within('[data-variant-name="White"]') do
              within('.column-price') { expect(page).to have_field(with: 11) }
            end
          end

          within("#option-#{size_option.id}") do
            click_on 'Edit'
            select_option_value('Extra Large', index: 3, create: true)
            click_on 'Done'
          end

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Black/Extra Large"]') do
              within('.column-price') { expect(page).to have_field(with: 10) }
            end

            within('[data-variant-name="White/Extra Large"]') do
              within('.column-price') { expect(page).to have_field(with: 11) }
            end
          end

          # Update product variants
          click_on 'Update', match: :first
          expect(page).to have_content('successfully updated')
          within('.alerts-container') { find('button').click }

          within('[data-test-id="product-variants-table"]') do
            within('[data-variant-name="Black/Extra Large"]') do
              within('.column-price') { expect(page).to have_field(with: 10) }
            end

            within('[data-variant-name="White/Extra Large"]') do
              within('.column-price') { expect(page).to have_field(with: 11) }
            end
          end

          expect(product.reload.variants.map(&:options_text)).to contain_exactly(
            'Color: Black, Size: Small',
            'Color: Black, Size: Medium',
            'Color: Black, Size: Large',
            'Color: Black, Size: Extra Large',
            'Color: White, Size: Small',
            'Color: White, Size: Medium',
            'Color: White, Size: Large',
            'Color: White, Size: Extra Large'
          )
        end
      end
    end

    context 'filtering products', js: true do
      it 'renders selected filters' do
        visit spree.admin_products_path

        fill_in 'q_multi_search', with: 'Backpack'

        within 'main' do
          click_on 'Filters'
        end

        within('#product-filters-drawer') do
          click_on 'Filter Results'
        end

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

          within('main') { click_on 'Filters' }

          within('#product-filters-drawer') do
            fill_in 'Tags', with: 'some tag'

            find('.ts-dropdown').click
            find('#q_tags_name_in-ts-label').click
            click_on 'Filter Results'
          end

          expect(page).to have_content(product.name)
          expect(page).not_to have_content(product_without_tag.name)
        end
      end
    end
  end
end
