require 'spec_helper'

module Spree
  RSpec.describe SearchProvider::Base do
    let(:store) { @default_store }
    let(:provider) { described_class.new(store) }

    describe '#initialize' do
      it 'stores the store' do
        expect(provider.store).to eq(store)
      end
    end

    describe '#search_and_filter' do
      it 'raises NotImplementedError' do
        expect { provider.search_and_filter(scope: Spree::Product.all) }.to raise_error(NotImplementedError)
      end
    end

    describe '#index' do
      it 'is a no-op by default' do
        expect { provider.index(build(:product)) }.not_to raise_error
      end
    end

    describe '#remove' do
      it 'is a no-op by default' do
        expect { provider.remove(build(:product)) }.not_to raise_error
      end
    end

    describe '#remove_by_id' do
      it 'is a no-op by default' do
        expect { provider.remove_by_id(1) }.not_to raise_error
      end
    end

    describe '#reindex' do
      it 'is a no-op by default' do
        expect { provider.reindex }.not_to raise_error
      end
    end
  end
end
