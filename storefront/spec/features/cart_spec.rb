require 'spec_helper'

describe 'Cart', type: :feature do
  let(:store) { Spree::Store.default }
  let(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:variant, product: product) }
  let(:line_item) { order.line_items.first }

  shared_examples 'renders cart page' do
    it 'shows total' do
      expect(page).to have_content('Total')
      expect(page).to have_content(order.display_item_total.to_html)
    end

    it 'shows line items' do
      expect(page).to have_content(line_item.name)
      expect(page).to have_content(line_item.display_total.to_html)
    end
  end

  shared_examples 'updates cart' do
    it 'can update line item quantity', js: true do
      within '#line-items:first-child' do
        find('.quantity-increase-button').click
      end

      wait_for_turbo

      within '#line-items:first-child' do
        expect(page).to have_field('line_item_quantity', with: '2')
      end
      expect(page).to have_content(line_item.price * 2)
      expect(order.reload.item_total).to eq(line_item.price * 2)

      within '#line-items:first-child' do
        find('.quantity-decrease-button').click
      end

      wait_for_turbo
      within '#line-items:first-child' do
        expect(page).to have_field('line_item_quantity', with: '1')
      end
      expect(page).to have_content(line_item.price)
      expect(order.reload.item_total).to eq(line_item.price)
    end

    it 'can remove line item' do
      line_item_name = line_item.name

      within '#line-items:first-child' do
        find('.remove-line-item-button').click
      end

      wait_for_turbo

      expect(page).to have_content('Your cart is empty')
      expect(page).not_to have_content(line_item_name)
    end
  end

  shared_examples 'renders empty cart page' do
    it 'renders empty cart page' do
      expect(page).to have_content('Your cart is empty')
    end
  end

  context 'order by token' do
    context 'order exists' do
      let(:order) { create(:order_with_line_items, store: store) }
      let(:order_token) { order.token }

      before do
        visit spree.cart_path(order_token: order_token)
      end

      it_behaves_like 'renders cart page'
      it_behaves_like 'updates cart'
    end

    context 'order does not exist' do
      before do
        visit spree.cart_path(order_token: 'invalid')
      end

      it_behaves_like 'renders empty cart page'
    end
  end

  context 'order by cookie' do
    context 'order exists', js: true do
      before do
        # Mock store url to match Capybara url for cookie domain
        allow_any_instance_of(Spree::LineItemsController).to receive(:current_store)
          .and_return(store)
        host = Capybara.current_session.server.host
        allow(store).to receive(:url_or_custom_domain).and_return(host)
        add_to_cart(product)
      end

      let(:order) { Spree::Order.last }

      it_behaves_like 'renders cart page'
      it_behaves_like 'updates cart'
    end

    context 'order does not exist' do
      before do
        visit spree.cart_path
      end

      it_behaves_like 'renders empty cart page'
    end
  end
end
