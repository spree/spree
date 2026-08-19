require 'spec_helper'

RSpec.describe 'Spree::Products status workflows' do
  let(:store) { Spree::Store.default }

  describe Spree::Products::Activate do
    let(:product) { create(:product, status: 'draft', store: store) }

    it 'puts the product on sale' do
      expect { described_class.call(product: product) }.to change { product.reload.status }.from('draft').to('active')
    end

    it 'publishes product.activated', events: true do
      allow(product).to receive(:publish_event).with(anything)
      expect(product).to receive(:publish_event).with('product.activated')

      described_class.call(product: product)
    end

    context 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'runs the after_activate hook' do
        seen = []
        Spree.hooks.register('products.activate.after_activate') { |workflow| seen << workflow.product }

        described_class.call(product: product)

        expect(seen).to eq([product])
      end

      it 'can be vetoed' do
        Spree.hooks.register('products.activate.validate') { |workflow| workflow.reject!('nope') }

        result = described_class.call(product: product)

        expect(result).not_to be_success
        expect(product.reload.status).to eq('draft')
      end
    end
  end

  describe Spree::Products::Archive do
    let(:product) { create(:product, status: 'active', store: store) }

    it 'takes the product off sale' do
      expect { described_class.call(product: product) }.to change { product.reload.status }.from('active').to('archived')
    end

    it 'publishes product.archived', events: true do
      allow(product).to receive(:publish_event).with(anything)
      expect(product).to receive(:publish_event).with('product.archived')

      described_class.call(product: product)
    end
  end

  describe Spree::Products::Draft do
    let(:product) { create(:product, status: 'active', store: store) }

    it 'returns the product to draft' do
      expect { described_class.call(product: product) }.to change { product.reload.status }.from('active').to('draft')
    end
  end
end
