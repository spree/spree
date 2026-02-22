require 'spec_helper'

describe Spree::Promotion::Rules::Currency, type: :model do
  let(:store) { @default_store }
  let(:rule) { described_class.new }
  let(:order) { create(:order, store: store) }

  context 'preferred currency is set' do
    before { rule.preferred_currency = 'EUR' }

    it 'is eligible for correct currency' do
      order.currency = 'EUR'
      expect(rule).to be_eligible(order)
      expect(rule.eligibility_errors).to be_empty
    end

    it 'is not eligible for incorrect currency' do
      order.currency = 'USD'
      expect(rule).not_to be_eligible(order)

      expect(rule.eligibility_errors.count).to eq(1)
      expect(rule.eligibility_errors.to_hash[:base]).to eq([Spree.t('eligibility_errors.messages.wrong_currency')])
    end
  end

  describe '#applicable?' do
    subject { rule.applicable?(promotable) }

    context 'when promotable is an order' do
      let(:promotable) { Spree::Order.new }
      it { is_expected.to be true }
    end

    context 'when promotable is not an order' do
      let(:promotable) { Spree::LineItem.new }
      it { is_expected.to be false }
    end
  end
end
