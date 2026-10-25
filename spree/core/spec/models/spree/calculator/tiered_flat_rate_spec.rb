require 'spec_helper'

describe Spree::Calculator::TieredFlatRate, type: :model do
  let(:calculator) { Spree::Calculator::TieredFlatRate.new }

  describe '#valid?' do
    subject { calculator.valid? }

    context 'when tiers is not a list of tiers' do
      before { calculator.preferred_tiers = ['nope', 0] }

      it { is_expected.to be false }
    end

    context 'when tiers is the pre-6.0 hash keyed by threshold' do
      before { calculator.preferred_tiers = { 100 => 15 } }

      it { is_expected.to be false }
    end

    context 'when a threshold is not a positive number' do
      before { calculator.preferred_tiers = [{ threshold: 'nope', value: 20 }] }

      it { is_expected.to be false }
    end

    context 'when a threshold repeats' do
      before { calculator.preferred_tiers = [{ threshold: 100, value: 15 }, { threshold: 100, value: 20 }] }

      it { is_expected.to be false }
    end

    context 'when an amount is negative' do
      before { calculator.preferred_tiers = [{ threshold: 100, value: -1 }] }

      it { is_expected.to be false }
    end

    context 'when every tier has a positive threshold and an amount' do
      before { calculator.preferred_tiers = [{ threshold: 100, value: 15 }] }

      it { is_expected.to be true }
    end
  end

  describe '#compute' do
    subject { calculator.compute(line_item) }

    let(:line_item) { create(:line_item) }

    before do
      calculator.preferred_base_amount = 10
      calculator.preferred_currency = 'USD'
      calculator.preferred_tiers = [
        { threshold: 200, value: 20 },
        { threshold: 100, value: 15 }
      ]
      allow(line_item).to receive_messages(currency: 'USD')
    end

    context 'when amount falls within the first tier' do
      before { allow(line_item).to receive_messages(amount: 50) }

      it { is_expected.to eq 10 }
    end

    context 'when amount falls within the second tier' do
      before { allow(line_item).to receive_messages(amount: 150) }

      it { is_expected.to eq 15 }
    end

    context 'when currency does not match' do
      before do
        calculator.preferred_currency = 'GBP'
        allow(line_item).to receive_messages(amount: 150)
      end

      it { is_expected.to eq 0 }
    end

    context 'when currency is blank' do
      before do
        calculator.preferred_currency = ''
        allow(line_item).to receive_messages(amount: 150)
      end

      it { is_expected.to eq 0 }
    end

    context 'when object currency is nil' do
      before do
        allow(line_item).to receive_messages(amount: 150, currency: nil)
      end

      it { is_expected.to eq 0 }
    end

    context 'when there is no object' do
      subject { calculator.compute }

      it { is_expected.to eq 0 }
    end
  end
end
