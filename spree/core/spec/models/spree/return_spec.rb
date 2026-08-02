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
  end
end
