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

  # Seeding a demo catalog shouldn't fan out a `product.created` per product to
  # webhooks and analytics. The import's own `import.*` events still fire.
  #
  # Runs without the wrapping transaction: lifecycle events fire on
  # `after_commit`, so inside one they'd all land after the suppression block
  # has exited — which is not how the jobs behave in production.
  describe 'skip_events', :events do
    self.use_transactional_tests = false

    let(:csv_path) { Spree::Core::Engine.root.join('db', 'sample_data', 'products.csv') }

    # Truncating tears down the suite-wide store/admin the transactional
    # examples share, so rebuild them for anything that runs afterwards.
    after do
      DatabaseCleaner.clean_with(:truncation)
      Spree::Seeds::All.call
    end

    # Drives the queued path, like production: each job is its own unit of
    # work, so a row's `after_commit` lands inside the suppression block.
    # (Inline runs everything in one `state_machines` transaction, which commits
    # — and so publishes — only after the block has exited.)
    def product_events_published(skip_events)
      names = []
      allow(Spree::Events).to receive(:publish).and_wrap_original do |original, name, *rest|
        names << name
        original.call(name, *rest)
      end

      described_class.call(csv_path: csv_path, import_class: Spree::Imports::Products,
                           skip_events: skip_events)
      perform_enqueued_jobs(only: [Spree::Imports::CreateRowsJob, Spree::Imports::ProcessRowsJob,
                                   Spree::Imports::ProcessGroupJob])

      names.count { |name| name.to_s.start_with?('product.') }
    end

    # Only the rows go quiet — the import's own lifecycle stays observable, so
    # a dashboard or subscriber can still tell when seeding finished.
    it 'still publishes the import lifecycle events' do
      names = []
      allow(Spree::Events).to receive(:publish).and_wrap_original do |original, name, *rest|
        names << name
        original.call(name, *rest)
      end

      described_class.call(csv_path: csv_path, import_class: Spree::Imports::Products,
                           skip_events: true)
      perform_enqueued_jobs(only: [Spree::Imports::CreateRowsJob, Spree::Imports::ProcessRowsJob,
                                   Spree::Imports::ProcessGroupJob])

      # The import's own lifecycle is untouched by the row suppression.
      expect(names).to include('import.created')
      expect(names.select { |name| name.to_s.start_with?('import.') }).to be_present
    end

    it 'travels with the import so the processing jobs see it' do
      import = described_class.call(csv_path: csv_path, import_class: Spree::Imports::Products,
                                    skip_events: true).value

      expect(Spree::Import.find(import.id).preferred_skip_events).to be true
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
