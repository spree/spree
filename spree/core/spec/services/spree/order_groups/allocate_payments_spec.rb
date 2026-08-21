require 'spec_helper'

RSpec.describe Spree::OrderGroups::AllocatePayments do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:group) { create(:order_group, store: store) }

  def payment_for(amount, status: 'completed')
    create(:payment, order: nil, cart: nil, order_group: group, amount: amount, status: status)
  end

  def shares_by_order
    group.orders.order(:id).map { |order| order.payment_splits.sum(:authorized_amount) }
  end

  # Totals that do not divide evenly, paid by two payments that likewise do
  # not. Each payment rounding on its own would hand one child a penny too
  # many and another a penny too few, so one reads overcharged and another
  # underpaid even though the group took exactly what it was owed.
  describe 'several payments against totals that do not divide evenly' do
    let!(:orders) do
      [BigDecimal('33.33'), BigDecimal('33.33'), BigDecimal('33.34')].map do |total|
        create(:order, store: store, order_group: group, seller: seller, total: total)
      end
    end

    before do
      payment_for(50)
      payment_for(50)
      described_class.call(group: group)
    end

    it 'gives each child exactly its own total' do
      expect(shares_by_order).to eq([BigDecimal('33.33'), BigDecimal('33.33'), BigDecimal('33.34')])
    end

    it 'shares out every penny the customer paid' do
      expect(Spree::PaymentSplit.sum(:authorized_amount)).to eq(100)
    end
  end

  describe 'one payment' do
    let!(:orders) do
      [BigDecimal('40'), BigDecimal('60')].map do |total|
        create(:order, store: store, order_group: group, total: total)
      end
    end

    before do
      payment_for(100)
      described_class.call(group: group)
    end

    it 'splits it by what each child is worth' do
      expect(shares_by_order).to eq([BigDecimal('40'), BigDecimal('60')])
    end

    it 'records a completed payment as captured' do
      expect(Spree::PaymentSplit.sum(:captured_amount)).to eq(100)
    end
  end

  describe 'a pending payment' do
    let!(:order) { create(:order, store: store, order_group: group, total: 25) }

    before do
      payment_for(25, status: 'pending')
      described_class.call(group: group)
    end

    it 'authorises the share without capturing it' do
      split = order.payment_splits.sole

      expect(split.authorized_amount).to eq(25)
      expect(split.captured_amount).to eq(0)
    end
  end

  describe 'replaying' do
    let!(:order) { create(:order, store: store, order_group: group, total: 25) }

    it 'writes each share once' do
      payment_for(25)
      described_class.call(group: group)

      expect { described_class.call(group: group.reload) }.not_to change { Spree::PaymentSplit.count }
    end
  end
end
