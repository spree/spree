require 'spec_helper'

RSpec.describe Spree::QuantityRule do
  describe 'defaults' do
    it 'lets anything through when nothing is declared' do
      rule = described_class.new

      expect(rule.minimum).to eq(1)
      expect(rule.multiple).to eq(1)
      expect(rule).to be_unrestricted
      expect(rule).to be_satisfied_by(7)
    end

    it 'treats zero and negative declarations as unset' do
      rule = described_class.new(minimum_order_quantity: 0, order_multiple: -5)

      expect(rule.minimum).to eq(1)
      expect(rule.multiple).to eq(1)
    end
  end

  describe '#satisfied_by?' do
    subject(:rule) { described_class.new(minimum_order_quantity: 48, order_multiple: 24) }

    it 'accepts the minimum and every step above it' do
      expect(rule).to be_satisfied_by(48)
      expect(rule).to be_satisfied_by(72)
      expect(rule).to be_satisfied_by(96)
    end

    it 'refuses anything below the minimum or off the step' do
      expect(rule).not_to be_satisfied_by(24)
      expect(rule).not_to be_satisfied_by(50)
      expect(rule).not_to be_satisfied_by(100)
    end

    # A minimum that does not sit on the multiple still has to be orderable,
    # so steps are counted from the minimum rather than from zero.
    context 'when the minimum is not itself a multiple' do
      subject(:rule) { described_class.new(minimum_order_quantity: 50, order_multiple: 24) }

      it 'admits its own minimum and steps from there' do
        expect(rule).to be_satisfied_by(50)
        expect(rule).to be_satisfied_by(74)
        expect(rule).not_to be_satisfied_by(48)
        expect(rule).not_to be_satisfied_by(72)
      end
    end
  end

  describe '#nearest_valid' do
    subject(:rule) { described_class.new(minimum_order_quantity: 48, order_multiple: 24) }

    it 'offers both neighbours around an invalid quantity' do
      expect(rule.nearest_valid(60)).to eq([48, 72])
    end

    it 'offers only the minimum when the quantity is below it' do
      expect(rule.nearest_valid(10)).to eq([48])
    end

    it 'collapses to one value when the quantity is already valid' do
      expect(rule.nearest_valid(72)).to eq([72])
    end
  end

  describe 'equality' do
    it 'compares on the resolved pair rather than the raw columns' do
      expect(described_class.new(minimum_order_quantity: nil, order_multiple: nil)).
        to eq(described_class.new(minimum_order_quantity: 1, order_multiple: 1))
    end
  end
end
