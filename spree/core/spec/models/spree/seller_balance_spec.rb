require 'spec_helper'

RSpec.describe Spree::SellerBalance, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  def earn(amount, currency: 'USD', status: 'completed')
    create(:seller_transfer, seller: seller, currency: currency, amount: amount, status: status,
                             order: create(:order, store: store, seller: seller, currency: currency))
  end

  describe '.for' do
    it 'reads earned, paid, pending and the balance off the ledger' do
      earn(40)
      earn(30)
      earn(-5)
      earn(25, status: 'pending')
      earn(10, status: 'unresolved')
      earn(7, status: 'failed')
      settled = create(:seller_payout, :completed, seller: seller, amount: 50)
      earn(50).update!(payout: settled)
      create(:seller_payout, seller: seller, amount: 15)

      balance = described_class.for(seller, 'USD')

      expect(balance.earned).to eq(115)
      expect(balance.paid).to eq(50)
      expect(balance.balance).to eq(65)
      expect(balance.pending).to eq(35)
      expect(balance.display_balance.to_s).to eq('$65.00')
    end

    it 'answers what Seller#balance answers' do
      earn(40)
      settled = create(:seller_payout, :completed, seller: seller, amount: 10)
      earn(10).update!(payout: settled)

      expect(described_class.for(seller, 'USD').balance).to eq(seller.balance('USD'))
    end

    it 'keeps another currency out' do
      earn(40)
      earn(30, currency: 'EUR')

      expect(described_class.for(seller, 'EUR').earned).to eq(30)
    end
  end
end
