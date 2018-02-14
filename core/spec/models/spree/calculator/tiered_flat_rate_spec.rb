require 'spec_helper'

describe Spree::Calculator::TieredFlatRate, type: :model do
  let(:calculator) { Spree::Calculator::TieredFlatRate.new }

  describe '#valid?' do
    subject { calculator.valid? }

    context 'when tiers is not a hash' do
      before { calculator.preferred_tiers = ['nope', 0] }
      it { is_expected.to be false }
    end
    context 'when tiers is a hash' do
      context 'and one of the keys is not a positive number' do
        before { calculator.preferred_tiers = { 'nope' => 20 } }
        it { is_expected.to be false }
      end
    end
  end

  describe '#compute' do
    subject { calculator.compute(line_item) }

    let(:line_item) { mock_model Spree::LineItem, amount: amount }

    before do
      calculator.preferred_base_amount = 10
      calculator.preferred_tiers = {
        100 => 15,
        200 => 20
      }
    end

    context 'when amount falls within the first tier' do
      let(:amount) { 50 }

      it { is_expected.to eq 10 }
    end
    context 'when amount falls within the second tier' do
      let(:amount) { 150 }

      it { is_expected.to eq 15 }
    end
  end
end
