require 'spec_helper'

describe Spree::Calculator::TieredPercent, type: :model do
  let(:calculator) { Spree::Calculator::TieredPercent.new }

  describe '#valid?' do
    subject { calculator.valid? }

    context 'when base percent is less than zero' do
      before { calculator.preferred_base_percent = -1 }

      it { is_expected.to be false }
    end

    context 'when base percent is greater than 100' do
      before { calculator.preferred_base_percent = 110 }

      it { is_expected.to be false }
    end

    context 'when tiers is not a list of tiers' do
      before { calculator.preferred_tiers = ['nope', 0] }

      it { is_expected.to be false }
    end

    context 'when a threshold is not a positive number' do
      before { calculator.preferred_tiers = [{ threshold: 'nope', value: 20 }] }

      it { is_expected.to be false }
    end

    context 'when a rate is not a percent' do
      before { calculator.preferred_tiers = [{ threshold: 10, value: 110 }] }

      it { is_expected.to be false }
    end
  end

  describe '#compute' do
    subject { calculator.compute(line_item) }

    let(:line_item) { create(:line_item) }

    before do
      calculator.preferred_base_percent = 10
      calculator.preferred_tiers = [
        { threshold: 100, value: 15 },
        { threshold: 200, value: 20 }
      ]
    end

    context 'when amount falls within the first tier' do
      before { allow(line_item).to receive_messages(amount: 50) }

      it { is_expected.to eq 5 }
    end

    context 'when amount falls within the second tier' do
      before { allow(line_item).to receive_messages(amount: 150) }

      it { is_expected.to eq 22.5 }
    end

    context 'when an unsaved tier is not a number' do
      before do
        calculator.preferred_tiers += [{ threshold: 'abc', value: 30 }]
        allow(line_item).to receive_messages(amount: 150)
      end

      it('skips it') { is_expected.to eq 22.5 }
    end
  end

  context 'when saved and loaded again' do
    it 'keeps the tiers as a list with exact decimals' do
      calculator.update!(preferred_tiers: [{ threshold: '100.5', value: '12.5' }])

      expect(described_class.find(calculator.id).preferred_tiers).to eq([{ 'threshold' => '100.5', 'value' => '12.5' }])
    end
  end
end
