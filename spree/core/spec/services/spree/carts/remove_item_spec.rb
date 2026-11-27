require 'spec_helper'

module Spree
  describe Carts::RemoveItem do
    subject { described_class }

    let(:cart) { create(:cart) }
    let!(:line_item) { create(:line_item, cart: cart, order: nil, variant: variant, price: nil) }
    let(:variant) { create(:variant, price: 20) }
    let(:execute) { subject.call cart: cart, variant: variant }
    let(:value) { execute.value }

    before { cart.recalculate_totals! }

    context 'single line item' do
      it 'removes the item from the cart' do
        expect(cart.reload.item_total).to eq 20
        expect { execute }.to change { cart.line_items.count }.by(-1)
        expect(execute).to be_success
        expect(value).to eq line_item
        expect(cart.reload.item_total).to eq 0
      end
    end

    context 'line items with more than one quantity' do
      let!(:line_item) { create(:line_item, cart: cart, order: nil, variant: variant, quantity: 2, price: nil) }

      it 'removes quantity from the line item' do
        expect { execute }.to change { cart.reload.item_total }.by(-20)
        expect(execute).to be_success
        expect(value).to eq line_item
        line_item.reload
        expect(cart.line_items.count).to eq 1
        expect(line_item.quantity).to eq 1
      end
    end

    context 'raise error' do
      let(:other_variant) { create(:variant) }
      let(:execute) { subject.call cart: cart, variant: other_variant }

      it 'when trying to remove a non-existing item' do
        expect { execute }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'not given a fulfillment' do
      it 'ensures updated fulfillments' do
        expect(cart).to receive(:ensure_updated_fulfillments)
        expect(execute).to be_success
      end
    end

    context 'when store_credits payment' do
      let(:cart) { create(:cart, customer: create(:user)) }
      let!(:payment) { create(:store_credit_payment, cart: cart, order: nil, amount: 10) }

      it 'invalidates the store credit payment' do
        expect { execute }.to change { cart.payments.store_credits.count }.by(-1)
      end
    end

    context 'with a gift card paying the whole total' do
      let!(:line_item) { create(:line_item, cart: cart, order: nil, variant: variant, quantity: 3, price: nil) }
      let(:gift_card) { create(:gift_card, amount: 100, store: cart.store) }

      before do
        create(:store_credit_payment_method)
        cart.apply_gift_card(gift_card)
      end

      it 'keeps the card on the cart and shrinks its payment to the new total' do
        expect(cart.reload.gift_card_total).to eq(60)

        expect(execute).to be_success

        expect(cart.reload.gift_card).to eq(gift_card)
        expect(cart.total).to eq(40)
        expect(cart.gift_card_total).to eq(40)
        expect(gift_card.reload.amount_used).to eq(40)
      end
    end
  end
end
