require 'spec_helper'

module Spree
  describe Carts::AddItem do
    subject { described_class }

    let(:cart) { create(:cart) }
    let(:variant) { create(:variant, price: 20) }
    let(:qty) { 1 }
    let(:execute) { subject.call(cart: cart, variant: variant, quantity: qty) }
    let(:value) { execute.value }
    let(:expected_line_item) { cart.reload.line_items.first }

    context 'add line item to cart' do
      it 'changes by one and recalculates totals' do
        expect { execute }.to change { cart.line_items.count }.by(1)
        expect(execute).to be_success
        expect(value).to eq expected_line_item
        expect(cart.reload.item_total).to eq 20
      end
    end

    context 'with same line item' do
      let!(:line_item) { create(:line_item, cart: cart, order: nil, variant: variant) }

      it 'increments the existing line item instead of adding a new one' do
        expect(execute).to be_success
        expect(value).to eq expected_line_item
        expect(cart.line_items.count).to eq 1
        expect(expected_line_item.quantity).to eq(line_item.quantity + 1)
      end
    end

    context 'not given a fulfillment' do
      it 'ensures updated fulfillments' do
        expect(cart).to receive(:ensure_updated_fulfillments)
        expect(execute).to be_success
      end
    end

    context 'with store_credits payment' do
      let(:cart) { create(:cart_with_line_items, customer: create(:user)) }
      let!(:payment) { create(:store_credit_payment, cart: cart, order: nil, amount: 5) }

      it 'invalidates the store credit payment' do
        expect { execute }.to change { cart.payments.store_credits.count }.by(-1)
      end
    end

    context 'running promotions' do
      let(:promotion) { create(:promotion, kind: :automatic) }
      let(:calculator) { Spree::Calculator::FlatRate.new(preferred_amount: 10) }

      context 'one active order promotion' do
        let!(:action) { Spree::Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }

        before do
          subject.call(cart: cart, variant: variant, quantity: 1)
          cart.reload
        end

        it 'creates valid discount on the cart' do
          subject.call(cart: cart, variant: variant, quantity: 1)
          expect(cart.discounts.to_a.sum(&:amount)).not_to eq 0
          expect(cart.reload.total).to eq 30
        end
      end

      context 'one active line item promotion' do
        let!(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promotion, calculator: calculator) }

        before do
          subject.call(cart: cart, variant: variant, quantity: 1)
          cart.reload
        end

        it 'creates valid line item discount on the cart' do
          subject.call(cart: cart, variant: variant, quantity: 1)
          expect(cart.discounts.for_line_items.to_a.sum(&:amount)).not_to eq 0
          expect(cart.reload.total).to eq 30
        end
      end

      context 'VAT for variant with percent promotion' do
        let!(:category) { Spree::TaxCategory.create name: 'Taxable Foo' }
        let!(:rate) do
          Spree::TaxRate.create(
            name: 'Tax Rate 1',
            amount: 0.25,
            included_in_price: true,
            tax_category: category,
            zone: create(:zone_with_country, default_tax: true)
          )
        end
        let(:variant) { create(:variant, price: 1000) }
        let(:calculator) { Spree::Calculator::PercentOnLineItem.new(preferred_percent: 50) }
        let!(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promotion, calculator: calculator) }

        it 'updates included_tax_total' do
          expect(cart.included_tax_total.to_f).to eq(0.00)
          subject.call(cart: cart, variant: variant, quantity: 1)
          expect(cart.reload.included_tax_total.to_f).to eq(100)
        end

        it 'updates included_tax_total after adding two line items' do
          subject.call(cart: cart, variant: variant, quantity: 1)
          expect(cart.reload.included_tax_total.to_f).to eq(100)
          subject.call(cart: cart, variant: variant, quantity: 1)
          expect(cart.reload.included_tax_total.to_f).to eq(200)
        end
      end
    end

    context 'pass valid params hash in options' do
      let(:options) { { quantity: 2, variant_id: variant.id } }
      let(:execute) { subject.call(cart: cart, variant: variant, quantity: nil, options: options) }

      it 'takes the quantity from options' do
        expect(execute).to be_success
        expect(cart.line_items.count).to eq 1
        line_item = cart.line_items.first
        expect(line_item.quantity).to eq 2
      end
    end

    context 'pass invalid arguments' do
      context 'different quantity in argument and in options' do
        let(:options) { { quantity: 2 } }
        let(:execute) { subject.call(cart: cart, variant: variant, quantity: 3, options: options) }

        it 'takes value from options' do
          expect(execute).to be_success
          line_item = cart.line_items.first
          expect(line_item.quantity).to eq 2
        end
      end

      context 'no quantity in argument nor in options' do
        let(:options) { {} }
        let(:execute) { subject.call(cart: cart, variant: variant, quantity: nil, options: options) }

        it 'sets the default' do
          expect(execute).to be_success
          line_item = cart.line_items.first
          expect(line_item.quantity).to eq 1
        end
      end

      context 'not permitted option' do
        let(:options) { { dummy_param: true } }
        let(:execute) { subject.call(cart: cart, variant: variant, quantity: 1, options: options) }

        it 'ignores the option' do
          expect(execute).to be_success
          line_item = cart.line_items.first
          expect(line_item.quantity).to eq 1
        end
      end

      context 'pass non-existing variant' do
        let(:other_variant) { create(:variant) }
        let(:execute) { subject.call(cart: cart, variant: other_variant, quantity: 1) }

        before { Spree::Variant.find(other_variant.id).destroy }

        it 'fails without adding a line item' do
          expect(execute).to be_failure
          cart.reload
          expect(cart.line_items.count).to eq 0
        end
      end

      context 'variant does not have the desired quantity' do
        let(:execute) { subject.call(cart: cart, variant: variant, quantity: 10) }

        before { variant.stock_items.first.update backorderable: false }

        it 'fails without adding a line item' do
          expect(execute).to be_failure
          cart.reload
          expect(cart.line_items.count).to eq 0
        end
      end

      context 'variant has been discontinued' do
        let(:variant) { create :variant, discontinue_on: 1.day.ago }
        let(:execute) { subject.call(cart: cart, variant: variant, quantity: 10) }

        it 'fails without adding a line item' do
          expect(execute).to be_failure
          cart.reload
          expect(cart.line_items.count).to eq 0
        end
      end
    end

    context 'pre-order before the scheduled publish date' do
      let(:store) { @default_store }
      let(:channel) { store.default_channel }
      let(:variant) { create(:variant, price: 20) }

      before do
        # No stock; the backorder_limit is the cap (not backorderable).
        variant.stock_items.first.update!(backorderable: false)
        variant.stock_items.first.set_count_on_hand(0)
        variant.update!(preorderable: true, backorder_limit: 5)

        # Scheduled to publish later — embargoed unless preorderable.
        publication = variant.product.product_publications.find_or_create_by!(channel: channel)
        publication.update!(published_at: 2.months.from_now)
        variant.product.product_publications.reset
      end

      it 'adds the not-yet-published, preorderable item to the cart' do
        expect { execute }.to change { cart.line_items.count }.by(1)
        expect(execute).to be_success
      end

      it 'caps the pre-order at the backorder_limit' do
        result = subject.call(cart: cart, variant: variant, quantity: 6)
        expect(result).to be_failure
        expect(cart.reload.line_items).to be_empty
      end

      context 'with no backorder_limit (unlimited)' do
        before { variant.update!(backorder_limit: nil) }

        it 'accepts a pre-order beyond any stock count' do
          result = subject.call(cart: cart, variant: variant, quantity: 100)
          expect(result).to be_success
          expect(cart.reload.line_items.first.quantity).to eq 100
        end
      end

      context 'when the variant is not preorderable' do
        before do
          # Plenty of stock so the publish embargo is the only rejection cause.
          variant.update!(preorderable: false)
          variant.stock_items.first.set_count_on_hand(10)
        end

        it 'is rejected because the product is not yet published' do
          expect(execute).to be_failure
          expect(cart.reload.line_items).to be_empty
        end
      end
    end

    context 'setting metadata' do
      context 'via metadata param' do
        let(:metadata) { { 'gift_message' => 'Happy Birthday!' } }
        let(:execute) { subject.call(cart: cart, variant: variant, quantity: qty, metadata: metadata) }

        it 'stores metadata on the line item' do
          expect(execute).to be_success
          cart.reload
          expect(cart.line_items.first.metadata).to eq metadata
        end
      end
    end

    context 'when variant has price in the cart currency, but with amount set to nil' do
      let(:call_workflow) { subject.call(cart: cart, variant: variant, quantity: 1) }

      before do
        allow(Spree::Config).to receive(:allow_empty_price_amount).and_return(true)
        variant.prices.first.update(amount: nil)
      end

      it 'does not add the item and returns failure' do
        expect(call_workflow).to be_failure
        expect(call_workflow.error).not_to be_nil
      end
    end

    context 'stock reservations' do
      let(:variant) { create(:variant, price: 20) }

      before do
        variant.stock_items.first.update!(backorderable: false)
        variant.stock_items.first.set_count_on_hand(10)
      end

      context 'when the cart is mid-checkout' do
        let(:cart) { create(:cart, email: 'buyer@example.com') }

        it 'creates a reservation for the new line item' do
          expect { execute }.to change { Spree::StockReservation.where(cart_id: cart.id).count }.by(1)
          expect(execute).to be_success
        end

        it 'fails when adding more than available and rolls back the line item' do
          variant.stock_items.first.set_count_on_hand(0)

          result = subject.call(cart: cart, variant: variant, quantity: 1)

          expect(result).to be_failure
          expect(cart.reload.line_items).to be_empty
        end
      end

      context 'when the cart is not yet in checkout' do
        let(:cart) { create(:cart) }

        it 'does not create a reservation' do
          expect { execute }.not_to change { Spree::StockReservation.count }
          expect(execute).to be_success
        end
      end

      context 'when stock_reservations_enabled is false' do
        let(:cart) { create(:cart, email: 'buyer@example.com') }

        before { stub_store_preferences(stock_reservations_enabled: false) }

        it 'does not create a reservation' do
          expect { execute }.not_to change { Spree::StockReservation.count }
          expect(execute).to be_success
        end
      end

      context 'when the variant is a capped pre-order with partial stock' do
        let(:cart) { create(:cart, email: 'buyer@example.com') }

        before do
          variant.update!(preorderable: true, backorder_limit: 5)
          variant.stock_items.first.set_count_on_hand(2)
        end

        it 'skips reservation and accepts quantities beyond on-hand stock' do
          result = subject.call(cart: cart, variant: variant, quantity: 5)

          expect(result).to be_success
          expect(Spree::StockReservation.where(cart_id: cart.id)).to be_empty
        end
      end
    end
  end
end
