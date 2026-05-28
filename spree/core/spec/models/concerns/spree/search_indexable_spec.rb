require 'spec_helper'

RSpec.describe Spree::SearchIndexable, type: :concern do
  include ActiveJob::TestHelper

  let(:store) { @default_store }
  let(:product) { create(:product) }

  describe '#search_presentation' do
    it 'returns an array of document hashes (one per market × locale)' do
      result = product.search_presentation(store)
      expect(result).to be_an(Array)
      expect(result.first[:product_id]).to eq(product.prefixed_id)
      expect(result.first[:name]).to eq(product.name)
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
      allow(Spree).to receive(:search_provider).and_return('Spree::SearchProvider::Meilisearch')
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
        provider = instance_double(Spree::SearchProvider::Meilisearch)
        allow(Spree::SearchProvider::Meilisearch).to receive(:new).with(store).and_return(provider)
        expect(provider).to receive(:index).with(product)

        product.add_to_search_index
      end

      it 'does not enqueue a job' do
        allow_any_instance_of(Spree::SearchProvider::Meilisearch).to receive(:index)
        product # trigger create jobs
        clear_enqueued_jobs

        expect {
          product.add_to_search_index
        }.not_to have_enqueued_job(Spree::SearchProvider::IndexJob)
      end
    end

    describe '#remove_from_search_index' do
      it 'calls provider.remove synchronously' do
        provider = instance_double(Spree::SearchProvider::Meilisearch)
        allow(Spree::SearchProvider::Meilisearch).to receive(:new).with(store).and_return(provider)
        expect(provider).to receive(:remove).with(product)

        product.remove_from_search_index
      end

      it 'does not enqueue a job' do
        allow_any_instance_of(Spree::SearchProvider::Meilisearch).to receive(:remove)
        product # trigger create jobs
        clear_enqueued_jobs

        expect {
          product.remove_from_search_index
        }.not_to have_enqueued_job(Spree::SearchProvider::RemoveJob)
      end
    end
  end
end
