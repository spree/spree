require 'spec_helper'

describe Spree::OrderContents, type: :model do
  subject { described_class.new(order) }

  let(:order) { Spree::Order.create }
  let(:variant) { create(:variant) }

  context '#add' do
    context 'given quantity is not explicitly provided' do
      it 'adds one line item' do
        line_item = subject.add(variant)
        expect(line_item.quantity).to eq(1)
        expect(order.line_items.size).to eq(1)
      end
    end

    context 'given a shipment' do
      it 'ensure shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        shipment = create(:shipment)
        expect(subject.order).not_to receive(:ensure_updated_shipments)
        expect(subject.order).to receive(:refresh_shipment_rates).with(Spree::ShippingMethod::DISPLAY_ON_BACK_END)
        expect(shipment).to receive(:update_amounts)
        subject.add(variant, 1, shipment: shipment)
      end
    end

    context 'not given a shipment' do
      it 'ensures updated shipments' do
        expect(subject.order).to receive(:ensure_updated_shipments)
        subject.add(variant)
      end
    end

    it 'adds line item if one does not exist' do
      line_item = subject.add(variant, 1)
      expect(line_item.quantity).to eq(1)
      expect(order.line_items.size).to eq(1)
    end

    it 'updates line item if one exists' do
      subject.add(variant, 1)
      line_item = subject.add(variant, 1)
      expect(line_item.quantity).to eq(2)
      expect(order.line_items.size).to eq(1)
    end

    it 'updates order totals' do
      expect(order.item_total.to_f).to eq(0.00)
      expect(order.total.to_f).to eq(0.00)

      subject.add(variant, 1)

      expect(order.item_total.to_f).to eq(19.99)
      expect(order.total.to_f).to eq(19.99)
    end

    context 'when store_credits payment' do
      let!(:payment) { create(:store_credit_payment, order: order) }

      it { expect { subject.add(variant, 1) }.to change { order.payments.store_credits.count }.by(-1) }
    end

    context 'running promotions' do
      let(:promotion) { create(:promotion) }
      let(:calculator) { Spree::Calculator::FlatRate.new(preferred_amount: 10) }

      shared_context 'discount changes order total' do
        before { subject.add(variant, 1) }
        it { expect(subject.order.total).not_to eq variant.price }
      end

      context 'one active order promotion' do
        let!(:action) { Spree::Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }

        it 'creates valid discount on order' do
          subject.add(variant, 1)
          expect(subject.order.adjustments.to_a.sum(&:amount)).not_to eq 0
        end

        include_context 'discount changes order total'
      end

      context 'one active line item promotion' do
        let!(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promotion, calculator: calculator) }

        it 'creates valid discount on order' do
          subject.add(variant, 1)
          expect(subject.order.line_item_adjustments.to_a.sum(&:amount)).not_to eq 0
        end

        include_context 'discount changes order total'
      end

      context 'VAT for variant with percent promotion' do
        let!(:category) { Spree::TaxCategory.create name: 'Taxable Foo' }
        let!(:rate) do
          Spree::TaxRate.create(
            amount: 0.25,
            included_in_price: true,
            calculator: Spree::Calculator::DefaultTax.create,
            tax_category: category,
            zone: create(:zone_with_country, default_tax: true)
          )
        end
        let(:variant) { create(:variant, price: 1000) }
        let(:calculator) { Spree::Calculator::PercentOnLineItem.new(preferred_percent: 50) }
        let!(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promotion, calculator: calculator) }

        it 'updates included_tax_total' do
          expect(order.included_tax_total.to_f).to eq(0.00)
          subject.add(variant, 1)
          expect(order.included_tax_total.to_f).to eq(100)
        end

        it 'updates included_tax_total after adding two line items' do
          subject.add(variant, 1)
          expect(order.included_tax_total.to_f).to eq(100)
          subject.add(variant, 1)
          expect(order.included_tax_total.to_f).to eq(200)
        end
      end
    end
  end

  context '#remove' do
    context 'given an invalid variant' do
      it 'raises an exception' do
        expect do
          subject.remove(variant, 1)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'given quantity is not explicitly provided' do
      it 'removes one line item' do
        line_item = subject.add(variant, 3)
        subject.remove(variant)

        expect(line_item.quantity).to eq(2)
      end
    end

    context 'given a shipment' do
      it 'ensure shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        subject.add(variant, 1) # line item
        shipment = create(:shipment)
        expect(subject.order).not_to receive(:ensure_updated_shipments)
        expect(shipment).to receive(:update_amounts)
        subject.remove(variant, 1, shipment: shipment)
      end
    end

    context 'not given a shipment' do
      it 'ensures updated shipments' do
        subject.add(variant, 1) # line item
        expect(subject.order).to receive(:ensure_updated_shipments)
        subject.remove(variant)
      end
    end

    it 'reduces line_item quantity if quantity is less the line_item quantity' do
      line_item = subject.add(variant, 3)
      subject.remove(variant, 1)

      expect(line_item.quantity).to eq(2)
    end

    context 'when store_credits payment' do
      let(:payment) { create(:store_credit_payment, order: order) }

      before do
        subject.add(variant, 1)
        payment
      end

      it { expect { subject.remove(variant, 1) }.to change { order.payments.store_credits.count }.by(-1) }
    end

    it 'removes line_item if quantity matches line_item quantity' do
      subject.add(variant, 1)
      removed_line_item = subject.remove(variant, 1)

      # Should reflect the change already in Order#line_item
      expect(order.line_items).not_to include(removed_line_item)
    end

    it 'updates order totals' do
      expect(order.item_total.to_f).to eq(0.00)
      expect(order.total.to_f).to eq(0.00)

      subject.add(variant, 2)

      expect(order.item_total.to_f).to eq(39.98)
      expect(order.total.to_f).to eq(39.98)

      subject.remove(variant, 1)
      expect(order.item_total.to_f).to eq(19.99)
      expect(order.total.to_f).to eq(19.99)
    end
  end

  context '#remove_line_item' do
    context 'given a shipment' do
      it 'ensure shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        line_item = subject.add(variant, 1)
        shipment = create(:shipment)
        expect(subject.order).not_to receive(:ensure_updated_shipments)
        expect(shipment).to receive(:update_amounts)
        subject.remove_line_item(line_item, shipment: shipment)
      end
    end

    context 'not given a shipment' do
      it 'ensures updated shipments' do
        line_item = subject.add(variant, 1)
        expect(subject.order).to receive(:ensure_updated_shipments)
        subject.remove_line_item(line_item)
      end
    end

    context 'when store_credits payment' do
      let(:payment) { create(:store_credit_payment, order: order) }

      before do
        @line_item = subject.add(variant, 1)
        payment
      end

      it { expect { subject.remove_line_item(@line_item) }.to change { order.payments.store_credits.count }.by(-1) }
    end

    it 'removes line_item' do
      line_item = subject.add(variant, 1)
      subject.remove_line_item(line_item)

      expect(order.reload.line_items).not_to include(line_item)
    end

    it 'updates order totals' do
      expect(order.item_total.to_f).to eq(0.00)
      expect(order.total.to_f).to eq(0.00)

      line_item = subject.add(variant, 2)

      expect(order.item_total.to_f).to eq(39.98)
      expect(order.total.to_f).to eq(39.98)

      subject.remove_line_item(line_item)
      expect(order.item_total.to_f).to eq(0.00)
      expect(order.total.to_f).to eq(0.00)
    end
  end

  context 'update cart' do
    let!(:shirt) { subject.add variant, 1 }

    let(:params) do
      { line_items_attributes: {
        '0' => { id: shirt.id, quantity: 3 }
      } }
    end

    it 'changes item quantity' do
      subject.update_cart params
      expect(shirt.quantity).to eq 3
    end

    it 'updates order totals' do
      expect do
        subject.update_cart params
      end.to change { subject.order.total }
    end

    context 'when store_credits payment' do
      let!(:payment) { create(:store_credit_payment, order: order) }

      it { expect { subject.update_cart params }.to change { order.payments.store_credits.count }.by(-1) }
    end

    context 'submits item quantity 0' do
      let(:params) do
        { line_items_attributes: {
          '0' => { id: shirt.id, quantity: 0 },
          '1' => { id: '666', quantity: 0 }
        } }
      end

      it 'removes item from order' do
        expect do
          subject.update_cart params
        end.to change { subject.order.line_items.count }
      end

      it 'doesnt try to update unexistent items' do
        filtered_params = { line_items_attributes: {
          '0' => { id: shirt.id, quantity: 0 }
        } }
        expect(subject.order).to receive(:update_attributes).with(filtered_params)
        subject.update_cart params
      end

      it 'does not filter if there is only one line item' do
        single_line_item_params = { line_items_attributes: { id: shirt.id, quantity: 0 } }
        expect(subject.order).to receive(:update_attributes).with(single_line_item_params)
        subject.update_cart single_line_item_params
      end
    end

    it 'ensures updated shipments' do
      expect(subject.order).to receive(:ensure_updated_shipments)
      subject.update_cart params
    end
  end

  context 'completed order' do
    let(:order) { create(:order, state: 'complete', completed_at: Time.current) }

    before { order.shipments.create! stock_location_id: variant.stock_location_ids.first }

    it 'updates order payment state' do
      expect do
        subject.add variant
      end.to change(order, :payment_state)

      expect do
        subject.remove variant
      end.to change(order, :payment_state)
    end
  end
end
