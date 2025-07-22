require 'spec_helper'

RSpec.describe 'Account wishlists', type: :feature do
  let(:user) { create(:user) }
  let(:product) { create(:product) }
  let(:store) { Spree::Store.default }
  let(:wishlist) { user.default_wishlist_for_store(store) }
  let!(:wishlist_item) { create(:wished_item, wishlist: wishlist, variant: product.master) }

  before do
    login_as(user, scope: :user)
    visit spree.account_wishlist_path
  end

  it 'allows user to add product from wishlist to cart' do
    expect(page).to have_content(product.name)

    within("#wished_item_#{wishlist_item.id}") do
      click_on Spree.t(:add_to_cart)
    end
    wait_for_turbo

    within 'turbo-frame#cart_summary' do |c|
      expect(c).to have_content("Total $#{product.price_in('USD').amount}")
    end
  end

  context 'when product is not available' do
    before do
      product.master.price_in('USD').destroy!
      visit spree.account_wishlist_path
    end

    it 'shows unavailable message' do
      expect(page).to have_content(product.name)

      within("#wished_item_#{wishlist_item.id}") do
        expect(page).not_to have_content(Spree.t(:add_to_cart))
        expect(page).to have_content(Spree.t('storefront.wished_items.unavailable'))
      end
    end
  end

  it 'allows user to remove product from wishlist' do
    expect(page).to have_content(product.name)

    within("#wished_item_#{wishlist_item.id}") do
      click_on Spree.t('storefront.wished_items.remove')
    end
    wait_for_turbo

    expect(page).not_to have_content(product.name)
    expect(wishlist.wished_items.count).to eq(0)
  end

  context 'when there are no wished items' do
    let!(:wishlist_item) { nil }

    it 'shows no wished items message' do
      expect(page).to have_content(Spree.t('storefront.wished_items.no_wished_items.title'))
      expect(page).to have_content(Spree.t('storefront.wished_items.no_wished_items.description'))
    end
  end

  it 'should link to product page' do
    click_on product.name
    expect(page).to have_current_path(spree.product_path(product))
  end
end
