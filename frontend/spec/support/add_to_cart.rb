def add_to_cart(product_name)
  visit spree.root_path
  click_link product_name
  expect(page).to have_selector('form#add-to-cart-form')
  expect(page).to have_selector(:button, id: 'add-to-cart-button', disabled: false)
  click_button 'add-to-cart-button'
  expect(page).to have_content(Spree.t(:shopping_cart))
end
