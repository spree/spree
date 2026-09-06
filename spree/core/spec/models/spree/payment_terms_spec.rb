require 'spec_helper'

RSpec.describe Spree::PaymentTerms do
  describe '#amount_due_now' do
    it 'is the whole total when terms are prepaid' do
      terms = described_class.new(kind: 'prepaid')

      expect(terms.amount_due_now(BigDecimal('100'), currency: 'USD')).to eq(BigDecimal('100'))
    end

    it 'takes the percentage when terms are a deposit' do
      terms = described_class.new(kind: 'deposit', deposit_percentage: 40)

      expect(terms.amount_due_now(BigDecimal('100'), currency: 'USD')).to eq(BigDecimal('40'))
    end

    # A buyer is never asked for less than the percentage agreed, and the
    # balance absorbs the fraction, so the two sum back to the total exactly.
    it 'rounds up so the deposit and balance still sum to the total' do
      terms = described_class.new(kind: 'deposit', deposit_percentage: BigDecimal('33.333'))
      total = BigDecimal('100')

      due = terms.amount_due_now(total, currency: 'USD')

      expect(due).to eq(BigDecimal('33.34'))
      expect(due + (total - due)).to eq(total)
    end

    it 'rounds to the currency own smallest unit, not two places' do
      terms = described_class.new(kind: 'deposit', deposit_percentage: 50)

      # Yen has no minor unit, so half of 101 is a whole yen, not 50.50.
      expect(terms.amount_due_now(BigDecimal('101'), currency: 'JPY')).to eq(BigDecimal('51'))
    end

    it 'never asks for more than the total' do
      terms = described_class.new(kind: 'deposit', deposit_percentage: 100)

      expect(terms.amount_due_now(BigDecimal('10'), currency: 'USD')).to eq(BigDecimal('10'))
    end
  end

  describe '.from_delivery_rate' do
    let(:store) { @default_store }

    it 'reads the terms the freight method declares' do
      method = create(:delivery_method, store: store, rate_provider: 'Spree::DeliveryRateProvider::Freight',
                                        deposit_percentage: 40, balance_due_label: 'Before shipping')
      rate = create(:delivery_rate, delivery_method: method)

      terms = described_class.from_delivery_rate(rate)

      expect(terms).to be_deposit
      expect(terms.deposit_percentage).to eq(40)
      expect(terms.balance_due_label).to eq('Before shipping')
      expect(terms.source).to eq('delivery_method')
    end

    it 'answers nothing for a method asking no deposit' do
      method = create(:delivery_method, store: store, rate_provider: 'Spree::DeliveryRateProvider::Freight')

      expect(described_class.from_delivery_rate(create(:delivery_rate, delivery_method: method))).to be_nil
    end

    it 'answers nothing for a provider with no notion of deposits' do
      expect(described_class.from_delivery_rate(create(:delivery_rate))).to be_nil
    end
  end

  describe 'round-tripping a snapshot' do
    it 'survives the trip through jsonb' do
      original = described_class.new(kind: 'deposit', deposit_percentage: BigDecimal('40'),
                                     balance_due_label: 'On arrival', source: 'delivery_method')

      rebuilt = described_class.from_snapshot(original.as_json)

      expect(rebuilt).to be_deposit
      expect(rebuilt.deposit_percentage).to eq(BigDecimal('40'))
      expect(rebuilt.balance_due_label).to eq('On arrival')
    end

    it 'answers nothing for an absent snapshot' do
      expect(described_class.from_snapshot(nil)).to be_nil
    end
  end
end
