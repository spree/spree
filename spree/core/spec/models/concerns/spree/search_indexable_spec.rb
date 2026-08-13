require 'spec_helper'

RSpec.describe Spree::SearchIndexable, type: :concern do
  include ActiveJob::TestHelper

  let(:store) { @default_store }
  let(:product) { create(:product) }

  # Stands in for a provider gem (spree_meilisearch): indexing is required, so
  # the concern enqueues jobs and calls through synchronously.
  let(:indexing_provider_class) do
    Class.new(Spree::SearchProvider::Base) do
      def self.indexing_required?
        true
      end

      def self.name
        'SearchIndexableSpec::IndexingProvider'
      end
    end
  end

  describe '#search_presentation' do
    it 'raises when no provider gem supplied a presenter' do
      expect { product.search_presentation(store) }.to raise_error(Spree::DependencyError, /search product presenter/)
    end

    it 'delegates to the configured presenter' do
      documents = [{ product_id: product.prefixed_id, name: product.name }]
      presenter_class = Class.new do
        def initialize(product, store); end
      end
      allow(Spree::Dependencies).to receive(:search_product_presenter_class).and_return(presenter_class)
      allow_any_instance_of(presenter_class).to receive(:call).and_return(documents)

      expect(product.search_presentation(store)).to eq(documents)
    end
  end

  context 'with database provider (default)' do
    it 'does not enqueue index jobs on update' do
      expect {
        product.update!(name: 'Updated Name')
      }.not_to have_enqueued_job(Spree::SearchProvider::IndexJob)
    end

    it 'does not enqueue remove jobs on destroy' do
      expect {
        product.destroy
      }.not_to have_enqueued_job(Spree::SearchProvider::RemoveJob)
    end

    describe '#add_to_search_index' do
      it 'is a no-op' do
        expect_any_instance_of(Spree::SearchProvider::Database).not_to receive(:index)
        product.add_to_search_index
      end
    end

    describe '#remove_from_search_index' do
      it 'is a no-op' do
        expect_any_instance_of(Spree::SearchProvider::Database).not_to receive(:remove)
        product.remove_from_search_index
      end
    end
  end

  context 'with external search provider' do
    before do
      stub_const(indexing_provider_class.name, indexing_provider_class)
      allow(Spree).to receive(:search_provider).and_return(indexing_provider_class.name)
    end

    after do
      allow(Spree).to receive(:search_provider).and_call_original
    end

    it 'enqueues index job on create' do
      expect {
        create(:product)
      }.to have_enqueued_job(Spree::SearchProvider::IndexJob).at_least(1).times
    end

    it 'enqueues index job on update' do
      product
      clear_enqueued_jobs
      expect {
        product.update!(name: 'Updated Name')
      }.to have_enqueued_job(Spree::SearchProvider::IndexJob)
    end

    it 'enqueues remove job on destroy' do
      product
      clear_enqueued_jobs
      expect {
        product.destroy
      }.to have_enqueued_job(Spree::SearchProvider::RemoveJob)
    end

    it 'passes model class name and stringified IDs for index job' do
      expect {
        create(:product)
      }.to have_enqueued_job(Spree::SearchProvider::IndexJob).with('Spree::Product', anything, store.id.to_s).at_least(1).times
    end

    describe '#add_to_search_index' do
      it 'calls provider.index synchronously' do
        provider = instance_double(indexing_provider_class)
        allow(indexing_provider_class).to receive(:new).with(store).and_return(provider)
        expect(provider).to receive(:index).with(product)

        product.add_to_search_index
      end

      it 'does not enqueue a job' do
        allow_any_instance_of(indexing_provider_class).to receive(:index)
        product # trigger create jobs
        clear_enqueued_jobs

        expect {
          product.add_to_search_index
        }.not_to have_enqueued_job(Spree::SearchProvider::IndexJob)
      end
    end

    describe '#remove_from_search_index' do
      it 'calls provider.remove synchronously' do
        provider = instance_double(indexing_provider_class)
        allow(indexing_provider_class).to receive(:new).with(store).and_return(provider)
        expect(provider).to receive(:remove).with(product)

        product.remove_from_search_index
      end

      it 'does not enqueue a job' do
        allow_any_instance_of(indexing_provider_class).to receive(:remove)
        product # trigger create jobs
        clear_enqueued_jobs

        expect {
          product.remove_from_search_index
        }.not_to have_enqueued_job(Spree::SearchProvider::RemoveJob)
      end
    end
  end
end
