require 'spec_helper'

describe Spree::StockReceipt, type: :model do
  let(:store) { @default_store }
  let(:purchase_order) { create(:purchase_order, :ordered, store: store, quantity: 10) }

  describe 'a delivery' do
    it 'is numbered, dated and owned by its document\'s store' do
      receipt = create(:stock_receipt, receivable: purchase_order)

      expect(receipt.number).to start_with('SR')
      expect(receipt.store).to eq(store)
      expect(receipt.received_at).to be_present
      expect(receipt.items.sole).to have_attributes(line: purchase_order.items.sole, quantity_accepted: 10)
    end

    it 'has to bring something' do
      receipt = build(:stock_receipt, receivable: purchase_order)
      receipt.items.clear

      expect(receipt).to be_invalid
      expect(receipt.errors[:items]).to be_present
    end

    it 'totals what it accepted and what it refused' do
      receipt = build(:stock_receipt, receivable: purchase_order, quantity_accepted: 7,
                                     quantity_rejected: 3, rejection_reason: 'damaged')

      expect(receipt.quantity_accepted_total).to eq(7)
      expect(receipt.quantity_rejected_total).to eq(3)
    end

    it 'is found from the document it was booked against' do
      receipt = create(:stock_receipt, receivable: purchase_order)

      expect(purchase_order.reload.stock_receipts).to eq([receipt])
    end
  end

  describe 'a line on it' do
    let(:line) { purchase_order.items.sole }
    let(:receipt) { create(:stock_receipt, receivable: purchase_order) }

    it 'counts accepted and rejected units together' do
      item = build(:stock_receipt_item, stock_receipt: receipt, line: line, quantity_accepted: 4,
                                        quantity_rejected: 1, rejection_reason: 'wrong_item')

      expect(item).to be_valid
      expect(item.quantity_counted).to eq(5)
      expect(item.variant).to eq(line.variant)
    end

    it 'must count something' do
      item = build(:stock_receipt_item, stock_receipt: receipt, line: line, quantity_accepted: 0)

      expect(item).to be_invalid
      expect(item.errors[:base]).to include(Spree.t('stock_receipt.errors.nothing_counted'))
    end

    it 'needs a known reason for whatever it refused' do
      item = build(:stock_receipt_item, stock_receipt: receipt, line: line, quantity_accepted: 4,
                                        quantity_rejected: 1)

      expect(item).to be_invalid
      expect(item.errors[:rejection_reason]).to be_present

      item.rejection_reason = 'crushed'
      expect(item).to be_invalid

      item.rejection_reason = 'damaged'
      expect(item).to be_valid
    end

    it 'refuses a negative count' do
      item = build(:stock_receipt_item, stock_receipt: receipt, line: line, quantity_accepted: -1)

      expect(item).to be_invalid
    end
  end
end
