require 'spec_helper'

describe 'Menu Edit', type: :feature do
  stub_authorization!

  let!(:store_1) { create(:store) }
  let!(:main_menu) { create(:menu, name: 'Main Menu', store: store_1) }
  let!(:menu_item) { create(:menu_item, menu: main_menu, parent: main_menu.root) }
  let(:file_path) { Rails.root + '../../spec/support/ror_ringer.jpeg' }

  context 'when link to URL the user can' do
    before do
      visit spree.edit_admin_menu_menu_item_path(main_menu, menu_item)
    end

    it 'set to open in a new window' do
      find('label', text: 'Open this link in a new window').click
      click_on 'Update'

      assert_admin_flash_alert_success('Menu item "Link To Somewhere" has been successfully updated!')
      expect(page).to have_checked_field('menu_item_new_window')
    end
  end

  context 'setting a home page link', js: true do
    before do
      visit spree.edit_admin_menu_menu_item_path(main_menu, menu_item)
    end

    it 'allows you to switch to home page link' do
      select2 'Home Page', from: 'Link To'
      expect(page).to have_text 'Click the Update button below to change the link.'
      click_on 'Update'

      assert_admin_flash_alert_success('Menu item "Link To Somewhere" has been successfully updated!')
      expect(page).to have_text 'This link takes you to your stores home page.'
    end
  end

  context 'setting the link to a product link', js: true do
    let!(:product_1) { create(:product, name: 'Blue Shoes') }
    let!(:product_2) { create(:product, name: 'Black Socks') }
    let!(:product_3) { create(:product, name: 'Green Shirt') }

    before do
      visit spree.edit_admin_menu_menu_item_path(main_menu, menu_item)
    end

    it 'allows you to switch to select a product and save' do
      select2 'Product', from: 'Link To'
      expect(page).to have_text 'Click the Update button below to change the link.'
      click_on 'Update'

      select2 product_2.name, from: 'Product', search: true
      click_on 'Update'

      assert_admin_flash_alert_success('Menu item "Link To Somewhere" has been successfully updated!')
      expect(page).to have_css('span.select2-selection', text: product_2.name)
      expect(page).to have_text("/products/#{product_2.slug}")
    end
  end

  context 'setting the link to a Taxon link', js: true do
    let!(:taxon_1) { create(:taxon) }
    let!(:taxon_2) { create(:taxon) }
    let!(:taxon_3) { create(:taxon) }

    before do
      visit spree.edit_admin_menu_menu_item_path(main_menu, menu_item)
    end

    it 'allows you to select a Taxon and save' do
      select2 'Taxon', from: 'Link To'
      expect(page).to have_text 'Click the Update button below to change the link.'
      click_on 'Update'

      select2 taxon_2.name, from: 'Taxon', search: true
      click_on 'Update'

      assert_admin_flash_alert_success('Menu item "Link To Somewhere" has been successfully updated!')
      expect(page).to have_css('span.select2-selection', text: taxon_2.pretty_name)
      expect(page).to have_text("/t/#{taxon_2.permalink}")
    end
  end

  context 'trying to save a menu item without a name' do
    before do
      visit spree.edit_admin_menu_menu_item_path(main_menu, menu_item)
    end

    it 'prompts you to enter a name' do
      fill_in 'Name', with: ''

      click_on 'Update'

      expect(page).to have_text "Name can't be blank"
    end
  end

  context 'when admin adds and removes an image icon' do
    before do
      visit spree.edit_admin_menu_menu_item_path(main_menu, menu_item)
    end

    it 'adds menu_item icon and removes when clicked' do
      attach_file('menu_item_icon_attributes_attachment', file_path)

      click_button 'Update'

      expect(page).to have_content('successfully updated!')
      expect(page).to have_css('#menuItemImgContainer img')

      click_link 'Remove Image'

      expect(page).to have_content('Image has been successfully removed')
      expect(page).not_to have_css('#menuItemImgContainer img')
    end
  end
end
