def add_to_cart(product)
  visit spree.product_path(product)

  expect(page).to have_selector('form#add-to-cart-form')
  expect(page).to have_selector(:button, id: 'add-to-cart-button', disabled: false)
  click_button 'add-to-cart-button'
  expect(page).to have_content(Spree.t(:added_to_cart))

  if block_given?
    yield
  else
    click_link 'View cart'
    expect(page).to have_content(Spree.t('cart_page.header').upcase)
  end
end
