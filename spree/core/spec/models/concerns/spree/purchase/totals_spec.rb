require 'spec_helper'

RSpec.shared_examples 'a purchase totals host' do
  describe '#quantity' do
    it 'sums line item quantities' do
      record = new_record_with_line_items
      record.line_items.first.update_column(:quantity, 3)

      expect(record.quantity).to eq(3)
    end
  end

  describe '#outstanding_balance?' do
    it 'reflects a non-zero balance' do
      expect(new_record(total: 10.10, payment_total: 9.50).outstanding_balance?).to be(true)
      expect(new_record(total: 8.25, payment_total: 10.44).outstanding_balance?).to be(true)
      expect(new_record(total: 10.10, payment_total: 10.10).outstanding_balance?).to be(false)
    end
  end

  describe '#paid?' do
    it 'requires a positive total fully covered by payments' do
      expect(new_record(total: 100, payment_total: 100)).to be_paid
      expect(new_record(total: 100, payment_total: 40)).not_to be_paid
      expect(new_record(total: 0, payment_total: 0)).not_to be_paid
    end
  end

  describe '#amount_due' do
    it 'nets applied store credit and never goes negative' do
      record = new_record(total: 100, payment_total: 40)

      allow(record).to receive(:total_applied_store_credit).and_return(70)
      expect(record.amount_due).to eq(0)

      allow(record).to receive(:total_applied_store_credit).and_return(10)
      expect(record.amount_due).to eq(50)
    end
  end

  describe '#fulfillment_discount' do
    it 'sums fulfillment-attached discounts as a positive amount' do
      record = new_record_with_line_items
      fulfillment = create_fulfillment(record)
      create_fulfillment_discount(record, fulfillment)

      expect(record.fulfillment_discount).to eq(4)
    end
  end
end

RSpec.describe Spree::Purchase::Totals do
  let(:store) { @default_store }

  context 'included in Spree::Cart' do
    def new_record(**attributes)
      build(:cart, store: @default_store, **attributes)
    end

    def new_record_with_line_items
      create(:cart_with_line_items, store: @default_store)
    end

    def create_fulfillment(record)
      create(:fulfillment, cart: record, order: nil)
    end

    def create_fulfillment_discount(record, fulfillment)
      create(:discount, order: nil, cart: record, line_item: nil, fulfillment: fulfillment, amount: -4, kind: 'promotion')
    end

    it_behaves_like 'a purchase totals host'
  end

  context 'included in Spree::Order' do
    def new_record(**attributes)
      build(:order, store: @default_store, **attributes)
    end

    def new_record_with_line_items
      create(:order_with_line_items, store: @default_store)
    end

    def create_fulfillment(record)
      create(:fulfillment, order: record)
    end

    def create_fulfillment_discount(record, fulfillment)
      create(:discount, order: record, cart: nil, line_item: nil, fulfillment: fulfillment, amount: -4, kind: 'promotion')
    end

    it_behaves_like 'a purchase totals host'
  end
end
