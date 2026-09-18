require 'spec_helper'

RSpec.describe Spree::Return do
  let(:store) { @default_store }

  it 'generates a prefixed number' do
    expect(create(:return, store: store).number).to start_with('RET')
  end

  it 'starts as requested' do
    expect(create(:return, store: store)).to be_requested
  end

  it 'requires at least one line item on create' do
    order = create(:shipped_order, store: store)
    record = described_class.new(
      store: store,
      order: order,
      stock_location: order.shipments.first.stock_location,
      status: described_class.default_status
    )

    expect(record).not_to be_valid
    expect(record.errors[:return_line_items]).to be_present
  end

  it 'is reachable from its order' do
    return_record = create(:return, store: store)

    expect(return_record.order.reload.returns).to include(return_record)
  end

  describe 'totals' do
    let(:return_record) { create(:return, store: store) }

    it 'sums what the customer is owed from the line items' do
      expect(return_record.refund_total).to eq(return_record.return_line_items.sum(&:pre_tax_amount))
    end

    it 'tracks how much has actually been refunded' do
      expect(return_record.refunded_total).to eq(0)
      expect(return_record.refundable_total).to eq(return_record.refund_total)
    end

    # The refund dialog offers refundable_total, so a figure still counting
    # units that never arrived is money out of the door (V-3654).
    context 'when the warehouse counted fewer units than were announced' do
      let(:return_record) { create(:received_return, store: store) }

      before do
        return_record.return_line_items.first.
          update!(quantity: 3, received_quantity: 2, pre_tax_amount: 269.97)
      end

      it 'owes only what arrived' do
        expect(return_record.refund_total).to eq(179.98)
        expect(return_record.refundable_total).to eq(179.98)
      end
    end

    # A third of a line does not divide, and this figure is the ceiling a
    # refund is checked against as well as the one the dialog offers.
    context 'when the share of the line does not divide evenly' do
      let(:return_record) { create(:received_return, store: store) }
      let(:line) { return_record.return_line_items.first }

      it 'rounds what arrived to the currency' do
        line.update!(quantity: 3, received_quantity: 2, pre_tax_amount: 10.00)

        expect(return_record.refund_total).to eq(6.67)
      end

      it 'owes the whole line back when every unit arrived' do
        line.update!(quantity: 3, received_quantity: 3, pre_tax_amount: 29.99)

        expect(return_record.refund_total).to eq(29.99)
      end
    end

    # The 5.x migration task writes the status but no received_at, so an
    # upgraded store's received returns must not fall back to what the
    # customer announced (V-3654).
    context 'when a migrated return carries no received_at' do
      let(:return_record) { create(:received_return, store: store) }

      before do
        return_record.return_line_items.first.
          update!(quantity: 3, received_quantity: 2, pre_tax_amount: 269.97)
        return_record.update_columns(received_at: nil)
      end

      it 'still owes only what arrived' do
        expect(return_record.reload.refund_total).to eq(179.98)
      end
    end
  end

  # The seller's clawback is built from these, so a line the warehouse never
  # counted must not appear: nothing came back, so nothing was earned back.
  describe '#refunded_line_amounts' do
    let(:return_record) { create(:received_return, store: store) }
    let(:line) { return_record.return_line_items.first }

    it 'names each line and what it is worth' do
      expect(return_record.refunded_line_amounts).to eq(line.line_item_id => line.pre_tax_amount)
    end

    it 'counts what was received rather than what was announced' do
      line.update!(received_quantity: 0)

      expect(return_record.refunded_line_amounts).to be_empty
    end
  end

  describe Spree::ReturnLineItem do
    let(:return_record) { create(:return, store: store) }
    let(:line) { return_record.return_line_items.first }

    # Refunding the list price would give back more than the customer paid
    # on a discounted line.
    it 'defaults the refundable amount to the paid share of the line' do
      line_item = line.line_item

      expect(line.pre_tax_amount).to eq(line_item.amount / line_item.quantity)
    end

    it 'requires a positive quantity' do
      line.quantity = 0

      expect(line).not_to be_valid
    end

    it 'starts with nothing received' do
      expect(line.received_quantity).to eq(0)
    end

    # Nothing has been counted yet, so what the customer announced is the only
    # measure of what the return will cost.
    it 'is owed the announced amount until the warehouse has counted' do
      expect(line.refund_amount).to eq(line.pre_tax_amount)
    end
  end
  describe '#to_package' do
    let(:order) { create(:shipped_order, store: store) }
    let(:return_record) { create(:return, order: order, store: store) }
    let(:fulfillment_item) { return_record.return_line_items.first.fulfillment_item }

    # The factory returns one unit; the shipment carried three.
    before { fulfillment_item.update_columns(quantity: 3) }

    # A partial return ships back what the customer is returning. Rating the
    # whole shipment buys the wrong postage and declares the wrong goods.
    it 'weighs only the units coming back' do
      expect(return_record.reload.to_package.contents.sum(&:quantity)).to eq(1)
    end

    it 'never rewrites what the shipment recorded as sent' do
      expect { return_record.reload.to_package }.not_to change { fulfillment_item.reload.quantity }
    end
  end
end
