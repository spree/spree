require 'spec_helper'

describe Spree::Preferences::ScopedStore, type: :model do
  subject { scoped_store }

  let(:scoped_store) { described_class.new(prefix, suffix) }

  let(:prefix) { nil }
  let(:suffix) { nil }

  describe '#store' do
    subject { scoped_store.store }

    it { is_expected.to be Spree::Preferences::Store.instance }
  end

  context 'stubbed store' do
    let(:store) { double(:store) }

    before do
      allow(scoped_store).to receive(:store).and_return(store)
    end

    context 'with a prefix' do
      let(:prefix) { 'my_class' }

      it 'can fetch' do
        expect(store).to receive(:fetch).with('my_class/attr')
        scoped_store.fetch('attr') { 'default' }
      end

      it 'can assign' do
        expect(store).to receive(:[]=).with('my_class/attr', 'val')
        scoped_store['attr'] = 'val'
      end

      it 'can delete' do
        expect(store).to receive(:delete).with('my_class/attr')
        scoped_store.delete('attr')
      end

      context 'and suffix' do
        let(:suffix) { 123 }

        it 'can fetch' do
          expect(store).to receive(:fetch).with('my_class/attr/123')
          scoped_store.fetch('attr') { 'default' }
        end

        it 'can assign' do
          expect(store).to receive(:[]=).with('my_class/attr/123', 'val')
          scoped_store['attr'] = 'val'
        end

        it 'can delete' do
          expect(store).to receive(:delete).with('my_class/attr/123')
          scoped_store.delete('attr')
        end
      end
    end
  end
end
