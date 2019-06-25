require 'spec_helper'

describe 'Properties', type: :feature, js: true do
  stub_authorization!

  before do
    visit spree.admin_products_path
  end

  context 'Property index' do
    before do
      create(:property, name: 'shirt size', presentation: 'size')
      create(:property, name: 'shirt fit', presentation: 'fit')
      visit spree.admin_properties_path
    end

    context 'listing product properties' do
      it 'lists the existing product properties' do
        within_row(1) do
          expect(column_text(1)).to eq('shirt size')
          expect(column_text(2)).to eq('size')
        end

        within_row(2) do
          expect(column_text(1)).to eq('shirt fit')
          expect(column_text(2)).to eq('fit')
        end
      end
    end

    context 'searching properties' do
      it 'lists properties matching search query' do
        click_on 'Filter'
        fill_in 'q_name_cont', with: 'size'
        click_on 'Search'

        expect(page).to have_content('shirt size')
        expect(page).not_to have_content('shirt fit')
      end
    end
  end

  context 'creating a property' do
    it 'allows an admin to create a new product property' do
      visit spree.admin_properties_path
      click_link 'new_property_link'
      within('.content-header') { expect(page).to have_content('New Property') }

      fill_in 'property_name', with: 'color of band'
      fill_in 'property_presentation', with: 'color'
      click_button 'Create'
      expect(page).to have_content('successfully created!')
    end
  end

  context 'editing a property' do
    before do
      create(:property)
      visit spree.admin_properties_path
      within_row(1) { click_icon :edit }
    end

    it 'allows an admin to edit an existing product property' do
      fill_in 'property_name', with: 'model 99'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')
      expect(page).to have_content('model 99')
    end

    it 'shows validation errors' do
      fill_in 'property_name', with: ''
      click_button 'Update'
      expect(page).to have_content("Name can't be blank")
    end
  end

  context 'linking a property to a product' do
    before do
      create(:product)
      create(:property, name: 'fooBar')
      visit spree.admin_products_path
      click_icon :edit
      within('#sidebar') do
        click_link 'Properties'
      end
    end

    # Regression test for #2279
    it 'successfully create and then remove product property' do
      fill_in_property
      # Sometimes the page doesn't load before the all check is done
      # lazily finding the element gives the page 10 seconds
      expect(page).to have_css('tbody#product_properties tr:nth-child(2)')
      expect(all('tbody#product_properties tr').count).to eq(2)

      delete_product_property

      check_property_row_count(1)
    end

    # Regression test for #4466
    it 'successfully remove and create a product property at the same time' do
      fill_in_property

      fill_in 'product_product_properties_attributes_1_property_name', with: 'New Property'
      fill_in 'product_product_properties_attributes_1_value', with: 'New Value'

      delete_product_property

      # Give fadeOut time to complete
      expect(page).not_to have_selector('#product_product_properties_attributes_0_property_name')
      expect(page).not_to have_selector('#product_product_properties_attributes_0_value')

      click_button 'Update'

      expect(page).not_to have_content('Product is not found')

      check_property_row_count(2)
    end

    it 'successfully create product property from existing properties' do
      fill_in 'product_product_properties_attributes_0_property_name', with: 'foo'
      find('#ui-id-2').click
      fill_in 'product_product_properties_attributes_0_value', with: 'bar'
      click_button 'Update'
      check_property_row_count(2)
    end

    def fill_in_property
      fill_in 'product_product_properties_attributes_0_property_name', with: 'A Property'
      fill_in 'product_product_properties_attributes_0_value', with: 'A Value'
      click_button 'Update'
      within('#sidebar') do
        click_link 'Properties'
      end
    end

    def delete_product_property
      spree_accept_alert do
        click_icon :delete
        wait_for_ajax
      end
    end

    def check_property_row_count(expected_row_count)
      within('#sidebar') do
        click_link 'Properties'
      end
      expect(page).to have_css('tbody#product_properties')
      expect(all('tbody#product_properties tr').count).to eq(expected_row_count)
    end
  end
end
