require 'spec_helper'

describe Spree::OrderContents, type: :model, db: :isolate do
  let(:order) { Spree::Order.create }
  let(:variant) { create(:variant) }

  subject { described_class.new(order) }

  context '#add' do
    context 'given quantity is not explicitly provided' do
      it 'should add one line item' do
        line_item = subject.add(variant)
        expect(line_item.quantity).to eq(1)
        expect(order.line_items.size).to eq(1)
      end
    end

    context 'variant is invalid' do
      it 'does not process line item' do
        variant.stock_items.update_all(backorderable: false)
        expect(Spree::PromotionHandler).to_not receive(:new)
        line_item = subject.add(variant)
        expect(line_item.valid?).to be(false)
        expect(order.line_items.include?(line_item)).to be(false)
      end
    end

    context 'given a shipment' do
      it 'ensures shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        shipment = create(:shipment)
        expect(subject.order).to_not receive(:ensure_updated_shipments)
        expect(shipment).to receive(:update_amounts)
        subject.add(variant, 1, nil, shipment)
      end

      context 'on new line item' do
        it 'populates target shipments' do
          shipment = create(:shipment)
          subject.add(variant, 1, nil, shipment)
          expect(order.line_items.first.target_shipment).to be(shipment)
        end
      end

      context 'on existing line item' do
        it 'populates target shipments' do
          shipment = create(:shipment)
          subject.add(variant, 1)
          expect(order.line_items.first.target_shipment).to be(nil)
          subject.add(variant, 1, nil, shipment)
          expect(order.line_items.first.target_shipment).to be(shipment)
          expect(order.line_items.first.price).to eql(variant.price)
        end
      end
    end

    context 'given a currency' do
      before do
        variant.prices.create!(currency: 'EUR', amount: 100)
      end

      context 'on new line item' do
        it 'attaches currency to line item' do
          order.currency = 'EUR'
          subject.add(variant, 1, order.currency)
          expect(order.line_items.first.currency).to be(order.currency)
          expect(order.line_items.first.price).to eql(100.to_d)
        end
      end

      context 'on existing line item' do
        it 'attaches currency to line item' do
          order.currency = 'EUR'
          subject.add(variant, 1)
          subject.add(variant, 1, order.currency)
          expect(order.line_items.first.currency).to be(order.currency)
          expect(order.line_items.first.price).to eql(100.to_d)
        end
      end
    end

    context 'not given a shipment' do
      it 'ensures updated shipments' do
        expect(subject.order).to receive(:ensure_updated_shipments)
        subject.add(variant)
      end
    end

    it 'should add line item if one does not exist' do
      line_item = subject.add(variant, 1)
      expect(line_item.quantity).to eq(1)
      expect(order.line_items.size).to eq(1)
      expect(order.line_items.first.price).to eql(variant.price)
    end

    it 'should update line item if one exists' do
      subject.add(variant, 1)
      line_item = subject.add(variant, 1)
      expect(line_item.quantity).to eq(2)
      expect(order.line_items.size).to eq(1)
      expect(order.line_items.first.price).to eql(variant.price)
    end

    it 'should update order totals' do
      expect(order.item_total.to_f).to eq(0.00)
      expect(order.total.to_f).to eq(0.00)

      subject.add(variant, 1)

      expect(order.item_total.to_f).to eq(19.99)
      expect(order.total.to_f).to eq(19.99)
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
    end
  end

  context '#remove' do
    context 'given an invalid variant' do
      it 'raises an exception' do
        expect {
          subject.remove(variant, 1)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'given quantity is not explicitly provided' do
      it 'should remove one line item' do
        line_item = subject.add(variant, 3)
        subject.remove(variant)

        expect(line_item.reload.quantity).to eq(2)
      end
    end

    context 'given a shipment' do
      it 'ensure shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        line_item = subject.add(variant, 1)
        shipment = create(:shipment)
        expect(subject.order).to_not receive(:ensure_updated_shipments)
        expect(shipment).to receive(:update_amounts)
        subject.remove(variant, 1, shipment)
      end
    end

    context 'not given a shipment' do
      it 'ensures updated shipments' do
        line_item = subject.add(variant, 1)
        expect(subject.order).to receive(:ensure_updated_shipments)
        subject.remove(variant)
      end
    end

    it 'should reduce line_item quantity if quantity is less the line_item quantity' do
      line_item = subject.add(variant, 3)
      subject.remove(variant, 1)

      expect(line_item.reload.quantity).to eq(2)
    end

    it 'should remove line_item if quantity matches line_item quantity' do
      subject.add(variant, 1)
      subject.remove(variant, 1)

      expect(order.reload.find_line_item_by_variant(variant)).to be_nil
    end

    it 'should update order totals' do
      expect(order.item_total.to_f).to eq(0.00)
      expect(order.total.to_f).to eq(0.00)

      subject.add(variant,2)

      expect(order.item_total.to_f).to eq(39.98)
      expect(order.total.to_f).to eq(39.98)

      subject.remove(variant,1)
      expect(order.item_total.to_f).to eq(19.99)
      expect(order.total.to_f).to eq(19.99)
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
      expect(shirt.reload.quantity).to eq 3
    end

    it 'updates order totals' do
      expect {
        subject.update_cart params
      }.to change { subject.order.total }
    end

    context 'submits item quantity 0' do
      let(:params) do
        { line_items_attributes: {
          '0' => { id: shirt.id, quantity: 0 }
        } }
      end

      it 'removes item from order' do
        expect {
          subject.update_cart params
        }.to change { subject.order.line_items.count }
      end
    end

    it 'ensures updated shipments' do
      expect(subject.order).to receive(:ensure_updated_shipments)
      subject.update_cart params
    end
  end

  context 'completed order' do
    let(:order) { create(:order, state: 'complete', completed_at: Time.now) }

    before { order.shipments.create! stock_location_id: variant.stock_location_ids.first }

    it 'updates order payment state' do
      expect {
        subject.add variant
      }.to change { order.payment_state }

      expect {
        subject.remove variant
      }.to change { order.payment_state }
    end
  end
end
