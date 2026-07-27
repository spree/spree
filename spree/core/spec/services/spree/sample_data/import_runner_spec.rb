require 'spec_helper'

RSpec.describe Spree::SampleData::ImportRunner, type: :service do
  let(:store) { @default_store }
  let!(:admin) { create(:admin_user) }
  let(:csv_path) { Spree::Core::Engine.root.join('db', 'sample_data', 'customers.csv') }

  before { store.add_user(admin) }

  subject(:result) { described_class.call(csv_path: csv_path, import_class: Spree::Imports::Customers) }

  it 'returns the queued import' do
    expect(result).to be_success
    expect(result.value).to be_a(Spree::Imports::Customers)
    expect(result.value.owner).to eq(store)
  end

  # The whole point of this runner: hand the CSV to the pipeline and return, so
  # a request never pays for the rows.
  it 'creates no rows of its own' do
    expect(result.value.rows).to be_empty
    expect(result.value.status).to eq('completed_mapping')
  end

  it 'enqueues row creation' do
    expect { result }.to have_enqueued_job(Spree::Imports::CreateRowsJob)
  end

  it 'auto-maps the sample CSV columns' do
    expect(result.value.mappings.mapped.pluck(:schema_field)).to include('email')
  end

  # The rake/seed path: same pipeline, performed in-process so the data exists
  # when the call returns. Uses product translations — a self-contained CSV that
  # doesn't pull in the address/newsletter side effects customers do.
  context 'inline' do
    let(:csv_path) { Spree::Core::Engine.root.join('db', 'sample_data', 'product_translations.csv') }

    subject(:result) do
      described_class.call(csv_path: csv_path, import_class: Spree::Imports::ProductTranslations, inline: true)
    end

    it 'completes the import before returning' do
      expect(result.value.status).to eq('completed')
      expect(result.value.rows.count).to be_positive
    end

    it 'enqueues nothing' do
      expect { result }.not_to have_enqueued_job(Spree::Imports::CreateRowsJob)
    end
  end

  it 'runs as an admin of the target store' do
    expect(result.value.user).to eq(admin)
  end

  context 'when the store has no admin' do
    before { store.users.each { |user| store.remove_user(user) } }

    it 'raises rather than attributing the import to an unrelated admin' do
      expect { result }.to raise_error(/No admin user found/)
    end
  end
end
