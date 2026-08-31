require 'spec_helper'

module Spree
  RSpec.describe Orders::CreateFromCart do
    let(:store) { @default_store }
    let(:customer) { create(:user) }
    let(:cart) do
      create(:cart_with_line_items, store: store, customer: customer, line_items_count: 2).tap do |cart|
        cart.update!(
          email: customer.email,
          customer_note: 'please quote for 10k units',
          metadata: { 'campaign' => 'trade-fair' }
        )
      end
    end

    it 'is registered as a dependency' do
      expect(Spree.order_create_from_cart_service).to eq(described_class)
    end

    describe '#call' do
      it 'copies the cart into a fresh draft order and leaves the cart untouched' do
        line_item = cart.line_items.first
        line_item.update_columns(price: 7.2, price_source: 'contract')

        result = described_class.call(cart: cart)

        expect(result).to be_success
        order = result.value

        expect(order).to be_a(Spree::Order)
        expect(order.status).to eq('draft')
        # NOT the completion copy: the one-shot cart_id slot stays free.
        expect(order.cart_id).to be_nil
        expect(order.token).to be_present
        expect(order.token).not_to eq(cart.token)

        expect(order.customer).to eq(customer)
        expect(order.email).to eq(customer.email)
        expect(order.currency).to eq(cart.currency)
        expect(order.customer_note).to eq('please quote for 10k units')
        expect(order.metadata['campaign']).to eq('trade-fair')

        # Line items come over with prices and provenance as they stand.
        expect(order.line_items.count).to eq(2)
        copied = order.line_items.find_by(variant_id: line_item.variant_id)
        expect(copied.price).to eq(7.2)
        expect(copied.price_source).to eq('contract')
        expect(copied.quantity).to eq(line_item.quantity)

        # No money records: the draft's own lifecycle rebuilds them.
        expect(order.payments).to be_empty

        # The cart is untouched — the buyer keeps shopping.
        expect(cart.reload.line_items.count).to eq(2)
        expect(cart.completed_at).to be_nil
        expect(line_item.reload.price).to eq(7.2)
      end

      it 'duplicates addresses instead of sharing rows' do
        create(:shipping_method) if Spree::DeliveryMethod.none?
        country = Spree::Country.by_iso('US')
        cart.update!(
          ship_address: create(:address, country: country, state: country.states.first),
          bill_address: create(:address, country: country, state: country.states.first)
        )

        order = described_class.call(cart: cart).value

        expect(order.ship_address_id).not_to eq(cart.ship_address_id)
        expect(order.ship_address.address1).to eq(cart.ship_address.address1)
        expect(order.bill_address_id).not_to eq(cart.bill_address_id)
      end

      it 'stamps created_by and honors a customer override' do
        admin = create(:admin_user)
        other_customer = create(:user)

        order = described_class.call(cart: cart, created_by: admin, customer: other_customer).value

        expect(order.created_by).to eq(admin)
        expect(order.customer).to eq(other_customer)
        expect(order.email).to eq(other_customer.email)
      end

      it 'fails without a cart' do
        result = described_class.call(cart: nil)

        expect(result).to be_failure
        expect(result.value).to eq(:cart_is_required)
      end
    end
  end
end
