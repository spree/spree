def add_to_cart(product_name)
  visit spree.root_path
  click_link product_name
  expect(page).to have_selector('form#add-to-cart-form')
  expect(page).to have_selector('button#add-to-cart-button')
  wait_for_condition do
    expect(page.find('#add-to-cart-button').disabled?).to eq(false)
  end
  click_button 'add-to-cart-button'
  wait_for_condition do
    expect(page).to have_content(Spree.t(:shopping_cart))
  end
end
