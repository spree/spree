# Syntax refactored version of: https://github.com/spree/spree/blob/master/frontend/spec/features/cart_spec.rb
require 'spec_helper'

feature 'Cart', inaccessible: true, js: true do
  scenario 'shows cart icon on non-cart pages' do
    visit spree.root_path
    expect(page).to have_selector 'li#link-to-cart a', visible: true
  end

  scenario 'prevents double clicking the remove button on cart' do
    create(:product, name: 'RoR Mug')

    visit spree.root_path
    click_link 'RoR Mug'
    click_button 'add-to-cart-button'

    # prevent form submit to verify button is disabled
    page.execute_script "$('#update-cart').on('submit',function(){return false;})"

    expect(page).not_to have_selector 'button#update-button[disabled]'
    page.find(:css, '.delete img').click
    expect(page).to have_selector 'button#update-button[disabled]'
  end

  # Regression test for #2006
  scenario "does not error out with a 404 when GET'ing to /orders/populate" do
    pending 'Unable to find css ".error" - spree frontend default css class definitions should be preserved'
    visit '/orders/populate'
    within('.error') do
      expect(page).to have_text Spree.t(:populate_get_error)
    end
  end

  scenario 'allows you to remove an item from the cart' do
    create(:product, name: 'RoR Mug')
    visit spree.root_path
    click_link 'RoR Mug'
    click_button 'add-to-cart-button'

    within('#line_items') do
      click_link 'delete_line_item_1'
    end

    expect(page).not_to have_text 'Line items quantity must be an integer'
    expect(page).not_to have_text 'RoR Mug'
    expect(page).to have_text 'Your cart is empty'
  end

  # regression for #2276
  context 'product contains variants but no option values' do
    given(:variant) { create(:variant) }
    given(:product) { variant.product }

    background { variant.option_values.destroy_all }

    scenario 'still adds product to cart', inaccessible: true do
      visit spree.product_path(product)
      click_button 'add-to-cart-button'
      visit spree.cart_path

      expect(page).to have_text product.name
    end
  end

  scenario "have a surrounding element with data-hook='cart_container'" do
    visit spree.cart_path
    expect(page).to have_selector "div[data-hook='cart_container']"
  end
end