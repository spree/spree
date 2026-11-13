require 'spec_helper'

RSpec.describe Spree::SearchProvider::ReindexJob, type: :job do
  let(:store) { @default_store }
  let!(:products) { create_list(:product, 3) }

  let(:provider_class) do
    Class.new(Spree::SearchProvider::Base) do
      def self.indexing_required?
        true
      end

      def self.name
        'ReindexJobSpec::IndexingProvider'
      end
    end
  end
  let(:provider) { provider_class.new(store) }

  let(:presenter_class) do
    Class.new do
      def initialize(product, _store)
        @product = product
      end

      def call
        [{ id: @product.prefixed_id }]
      end
    end
  end

  before do
    stub_const(provider_class.name, provider_class)
    allow(Spree).to receive(:search_provider).and_return(provider_class.name)
    allow(provider_class).to receive(:new).with(store).and_return(provider)
    allow(Spree::Dependencies).to receive(:search_product_presenter_class).and_return(presenter_class)
    stub_const("#{described_class}::BATCH_SIZE", 2)
  end

  it 'pushes the settings, then upserts every product document in batches' do
    expect(provider).to receive(:ensure_index_settings!).ordered
    expect(provider).to receive(:index_batch).with(products.first(2).map { |p| { id: p.prefixed_id } }).ordered
    expect(provider).to receive(:index_batch).with([{ id: products.last.prefixed_id }]).ordered

    described_class.perform_now(store.id.to_s)
  end

  it 'keeps existing documents unless asked to clear the index' do
    expect(provider).not_to receive(:clear_index)
    allow(provider).to receive(:index_batch)

    described_class.perform_now(store.id.to_s)
  end

  it 'clears the index between pushing the settings and rebuilding when asked' do
    expect(provider).to receive(:ensure_index_settings!).ordered
    expect(provider).to receive(:clear_index).ordered
    expect(provider).to receive(:index_batch).twice.ordered

    described_class.perform_now(store.id.to_s, clear: true)
  end

  it 'resumes after the last product indexed rather than starting over' do
    job = described_class.new(store.id.to_s)
    job.continuation = ActiveJob::Continuation.new(job, 'completed' => ['push_settings'],
                                                        'current' => ['index_products', products.first.id])

    expect(provider).not_to receive(:ensure_index_settings!)
    expect(provider).to receive(:index_batch).with(products.drop(1).map { |p| { id: p.prefixed_id } })

    job.perform_now
  end

  it 'does nothing for a provider that keeps no index' do
    allow(Spree).to receive(:search_provider).and_return('Spree::SearchProvider::Database')

    expect { described_class.perform_now(store.id.to_s) }.not_to raise_error
  end

  it 'does nothing if store is not found' do
    expect { described_class.perform_now('0') }.not_to raise_error
  end
end
