require 'spec_helper'

describe Spree::Calculator, type: :model do
  let(:order) { build(:order) }
  let(:line_item) { build(:line_item, order: order) }
  let(:shipment) { build(:shipment, order: order) }

  context 'with computable' do
    context 'and compute methods stubbed out' do
      context 'with a Spree::LineItem' do
        it 'calls compute_line_item' do
          expect(subject).to receive(:compute_line_item).with(line_item)
          subject.compute(line_item)
        end
      end

      context 'with a Spree::Order' do
        it 'calls compute_order' do
          expect(subject).to receive(:compute_order).with(order)
          subject.compute(order)
        end
      end

      context 'with a Spree::Shipment' do
        it 'calls compute_shipment' do
          expect(subject).to receive(:compute_shipment).with(shipment)
          subject.compute(shipment)
        end
      end

      context 'with an arbitrary object' do
        it 'calls the correct compute' do
          s = 'Calculator can all'
          expect(subject).to receive(:compute_string).with(s)
          subject.compute(s)
        end
      end
    end

    context 'with no stubbing' do
      context 'with a Spree::LineItem' do
        it 'raises NotImplementedError' do
          expect { subject.compute(line_item) }.to raise_error NotImplementedError, /Please implement \'compute_line_item\(line_item\)\' in your calculator/
        end
      end

      context 'with a Spree::Order' do
        it 'raises NotImplementedError' do
          expect { subject.compute(order) }.to raise_error NotImplementedError, /Please implement \'compute_order\(order\)\' in your calculator/
        end
      end

      context 'with a Spree::Shipment' do
        it 'raises NotImplementedError' do
          expect { subject.compute(shipment) }.to raise_error NotImplementedError, /Please implement \'compute_shipment\(shipment\)\' in your calculator/
        end
      end

      context 'with an arbitrary object' do
        it 'raises NotImplementedError' do
          s = 'Calculator can all'
          expect { subject.compute(s) }.to raise_error NotImplementedError, /Please implement \'compute_string\(string\)\' in your calculator/
        end
      end
    end
  end

  describe '.default_currency' do
    # The default is evaluated for every new calculator (including during
    # seeding, before a store exists), so it must not go through the
    # deprecated Spree::Store.default fallback.
    it 'does not use the deprecated Spree::Store.default fallback' do
      expect(Spree::Store).not_to receive(:default)

      described_class.default_currency
    end

    context 'with a default store' do
      let!(:store) { create(:store, default: true, default_currency: 'EUR') }

      it "returns the store's default currency" do
        expect(described_class.default_currency).to eq('EUR')
      end
    end

    context 'without a default store', without_global_store: true do
      before { Spree::Store.where(default: true).delete_all }

      it 'returns nil' do
        expect(described_class.default_currency).to be_nil
      end
    end
  end
end
