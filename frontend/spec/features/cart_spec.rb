require 'spec_helper'

describe 'Cart', type: :feature, inaccessible: true, js: true do
  before { Timecop.scale(100) }

  after { Timecop.return }

  let!(:variant) { create(:variant) }
  let!(:product) { variant.product }

  def add_mug_to_cart
    add_to_cart(product.name)
  end

  it 'shows cart icon on non-cart pages' do
    visit spree.root_path
    expect(page).to have_selector('li#link-to-cart a', visible: true)
  end

  it 'prevents double clicking the remove button on cart' do
    add_mug_to_cart
    # prevent form submit to verify button is disabled
    find('#update-cart').execute_script('$(this).submit(function(){return false;})')

    expect(page).not_to have_selector('button#update-button[disabled]')
    page.find(:css, '.delete span').click
    expect(page).to have_selector('button#update-button[disabled]')
  end

  it 'allows you to remove an item from the cart' do
    add_mug_to_cart
    line_item = Spree::LineItem.first!
    within('#line_items') do
      click_link "delete_line_item_#{line_item.id}"
    end

    expect(page).not_to have_content('Line items quantity must be an integer')
    expect(page).not_to have_content(product.name)
    expect(page).to have_content('Your cart is empty')

    within '#link-to-cart' do
      expect(page).to have_content('Empty')
    end
  end

  it 'allows you to empty the cart' do
    add_mug_to_cart
    expect(page).to have_content(product.name)
    click_on 'Empty Cart'
    expect(page).to have_content('Your cart is empty')

    within '#link-to-cart' do
      expect(page).to have_content('Empty')
    end
  end

  # regression for #2276
  context 'product contains variants but no option values' do
    before { variant.option_values.destroy_all }

    it 'still adds product to cart' do
      add_mug_to_cart
      visit spree.cart_path
      expect(page).to have_content(product.name)
    end
  end

  it "has a surrounding element with data-hook='cart_container'" do
    visit spree.cart_path
    expect(page).to have_selector("div[data-hook='cart_container']")
  end

  describe 'add promotion coupon on cart page' do
    let!(:promotion) { Spree::Promotion.create(name: 'Huhuhu', code: 'huhu') }
    let!(:calculator) { Spree::Calculator::FlatPercentItemTotal.create(preferred_flat_percent: '10') }
    let!(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator) }

    before do
      promotion.actions << action
      add_mug_to_cart
      expect(page).to have_current_path(spree.cart_path(variant_id: variant))
    end

    def apply_coupon(code)
      fill_in 'Coupon Code', with: code
      click_on 'Update'
    end

    context 'valid coupon' do
      before { apply_coupon(promotion.code) }

      context 'for the first time' do
        it 'makes sure payment reflects order total with discounts' do
          expect(page).to have_content(promotion.name)
        end
      end

      context 'same coupon for the second time' do
        before { apply_coupon(promotion.code) }

        it 'reflects an error that coupon already applied' do
          apply_coupon(promotion.code)
          expect(page).to have_content(Spree.t(:coupon_code_already_applied))
          expect(page).to have_content(promotion.name)
        end
      end
    end

    context 'invalid coupon' do
      it 'doesnt create a payment record' do
        apply_coupon('invalid')
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
      end
    end

    context "doesn't fill in coupon code input" do
      it 'advances just fine' do
        click_on 'Update'
        expect(page).to have_current_path(spree.cart_path)
      end
    end
  end
end
