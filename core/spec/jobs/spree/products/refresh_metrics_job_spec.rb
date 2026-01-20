require 'spec_helper'

RSpec.describe Spree::Products::RefreshMetricsJob, type: :job do
  describe '#perform' do
    let(:store) { @default_store }
    let(:product) { create(:product, stores: [store]) }
    let(:store_product) { product.store_products.find_by(store: store) }

    subject { described_class.perform_now(product.id, store.id) }

    context 'when store_product exists' do
      it 'calls refresh_metrics! on the store_product' do
        expect_any_instance_of(Spree::StoreProduct).to receive(:refresh_metrics!)

        subject
      end
    end

    context 'when store_product does not exist' do
      subject { described_class.perform_now(product.id, create(:store).id) }

      it 'does nothing' do
        expect_any_instance_of(Spree::StoreProduct).not_to receive(:refresh_metrics!)

        subject
      end
    end

    context 'when product_id is invalid' do
      subject { described_class.perform_now('non-existent-id', store.id) }

      it 'does nothing' do
        expect_any_instance_of(Spree::StoreProduct).not_to receive(:refresh_metrics!)

        subject
      end
    end

    context 'when store_id is invalid' do
      subject { described_class.perform_now(product.id, 'non-existent-id') }

      it 'does nothing' do
        expect_any_instance_of(Spree::StoreProduct).not_to receive(:refresh_metrics!)

        subject
      end
    end
  end
end
