require 'spec_helper'

module Spree
  RSpec.describe SearchProvider::Base do
    let(:store) { @default_store }
    let(:provider) { described_class.new(store) }

    describe '#search_and_filter' do
      it 'raises NotImplementedError' do
        expect { provider.search_and_filter(scope: Spree::Product.all) }.to raise_error(NotImplementedError)
      end
    end
  end
end
