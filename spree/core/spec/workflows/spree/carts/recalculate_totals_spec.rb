require 'spec_helper'

module Spree
  RSpec.describe Carts::RecalculateTotals do
    let(:store) { @default_store }

    describe 'live records' do
      let(:order) { create(:order_with_line_items, store: store, line_items_count: 2, line_items_price: 10) }

      it 'recomputes item count and money totals from the rows and persists them' do
        order.update_columns(item_total: 0, total_quantity: 0, total: 0)

        result = described_class.call(cart: order)

        expect(result).to be_success
        order.reload
        expect(order.total_quantity).to eq(2)
        expect(order.item_total).to eq(20)
        expect(order.total).to eq(order.item_total + order.delivery_total + order.adjustment_total)
      end

      it 'nets refunds out of the payment total' do
        order = create(:completed_order_with_totals, store: store)
        payment = create(:payment, order: order, amount: order.total, status: 'completed')
        create(:refund, payment: payment, amount: 5)

        described_class.call(cart: order)

        expect(order.reload.payment_total).to eq(payment.amount - 5)
      end

      it 'leaves the derived statuses alone, so a stale instance cannot undo them' do
        order = create(:completed_order_with_totals, store: store)
        Spree::Order.where(id: order.id).update_all(payment_status: 'refunded', fulfillment_status: 'fulfilled')
        order.send(:write_attribute, :payment_status, 'paid')
        order.send(:write_attribute, :fulfillment_status, 'pending')

        described_class.call(cart: order)

        order.reload
        expect(order.payment_status).to eq('refunded')
        expect(order.fulfillment_status).to eq('fulfilled')
      end
    end

    describe 'the completed-order money freeze' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'never regenerates typed rows but re-sums them (the post-placement resum path)' do
        # The order's own provider, not the global default — selection is
        # per-market since 6.0, so stubbing the global would assert nothing.
        provider = instance_double(Spree::TaxProvider::Internal)
        allow(order).to receive(:tax_provider).and_return(provider)
        expect(provider).not_to receive(:estimate)

        line_item = order.line_items.first
        order.discounts.create!(line_item: line_item, label: 'Manual', amount: -3,
                                kind: 'manual', value: 3, value_type: 'flat')

        expect { described_class.call(cart: order) }
          .to change { order.reload.discount_total }.by(0).and change { order.reload.adjustment_total }.by(-3)
      end

      # A commission settles between the platform and the seller, so the
      # columns report it beside what the shopper owes and never inside it.
      # The fee and its tax stay apart because the tax is separately
      # reportable on both sides of that supply.
      it 're-sums the commission lines without charging them to the customer' do
        seller = create(:seller, :approved, store: store)
        create(:commission_line, order: order, seller: seller,
                                 line_item: order.line_items.first,
                                 amount: 8, tax_amount: 2, total: 10)
        order.update_columns(commission_amount_total: 0, commission_tax_total: 0,
                             commission_total: 0)

        total_before = order.total
        adjustment_before = order.adjustment_total

        described_class.call(cart: order)

        order.reload
        expect(order).to have_attributes(commission_amount_total: 8,
                                         commission_tax_total: 2,
                                         commission_total: 10)
        expect(order.total).to eq(total_before)
        expect(order.adjustment_total).to eq(adjustment_before)
      end

      it 'reports no commission on an order nobody was charged for' do
        order.update_columns(commission_amount_total: 9, commission_tax_total: 90,
                             commission_total: 99)

        described_class.call(cart: order)

        expect(order.reload).to have_attributes(commission_amount_total: 0,
                                                commission_tax_total: 0,
                                                commission_total: 0)
      end
    end

    describe 'carts' do
      let(:cart) { create(:cart_with_line_items, store: store, line_items_count: 1, line_items_price: 15) }

      it 'recomputes cart totals through the same flow' do
        cart.update_columns(item_total: 0, total: 0, total_quantity: 0)

        described_class.call(cart: cart)

        cart.reload
        expect(cart.item_total).to eq(15)
        expect(cart.total_quantity).to eq(1)
        expect(cart.total).to eq(cart.item_total + cart.delivery_total + cart.adjustment_total)
      end

      # A cart has no commission_lines association at all, so the guard in
      # refresh_commission_totals is what stops the re-sum raising here.
      it 'recalculates without reaching for commission a cart cannot have' do
        expect(cart).not_to respond_to(:commission_lines)

        expect { described_class.call(cart: cart) }.not_to raise_error
        expect(described_class.call(cart: cart)).to be_success
      end

      # Totals move without the items changing (delivery, a coupon, tax), and
      # nothing else resizes the card's payment to follow them.
      context 'with a gift card paying towards it' do
        let(:gift_card) { create(:gift_card, amount: 100, store: store) }
        let(:line_item) { cart.line_items.first }
        let(:gift_card_payment) { cart.reload.payments.store_credits.checkout.first }

        before do
          create(:store_credit_payment_method)
          cart.apply_gift_card(gift_card)
        end

        it 'grows the gift card payment when the total rises' do
          line_item.update_column(:price, 25)

          described_class.call(cart: cart)

          expect(gift_card_payment.amount).to eq(cart.reload.total)
          expect(gift_card.reload.amount_used).to eq(cart.total)
        end

        it 'shrinks it and returns the difference to the card when the total falls' do
          line_item.update_column(:price, 5)

          described_class.call(cart: cart)

          expect(gift_card_payment.amount).to eq(cart.reload.total)
          expect(gift_card.reload.amount_used).to eq(cart.total)
        end

        it 'releases the card and restores its balance when nothing is left to pay' do
          line_item.update_column(:price, 0)

          described_class.call(cart: cart)

          expect(cart.reload.gift_card).to be_nil
          expect(cart.payments.store_credits.checkout).to be_empty
          expect(gift_card.reload.amount_used).to eq(0)
        end

        it 'draws no more from a card that has expired since it was applied' do
          paid = gift_card_payment.amount
          gift_card.update_column(:expires_at, 1.day.ago)
          line_item.update_column(:price, 25)

          described_class.call(cart: cart)

          expect(gift_card_payment.reload.amount).to eq(paid)
          expect(gift_card.reload.amount_used).to eq(paid)
        end

        it 'keeps what the card already pays when its amount is lowered below that' do
          paid = gift_card_payment.amount
          gift_card.update_column(:amount, 1)
          line_item.update_column(:price, 25)

          described_class.call(cart: cart)

          expect(gift_card_payment.reload.amount).to eq(paid)
        end

        it 'leaves a resized payment that completion can still take' do
          line_item.update_column(:price, 25)
          described_class.call(cart: cart)

          gift_card_payment.purchase!

          expect(gift_card_payment.reload).to be_completed
        end
      end
    end
  end
end
