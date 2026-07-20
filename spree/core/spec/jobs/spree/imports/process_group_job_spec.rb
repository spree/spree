require 'spec_helper'

RSpec.describe Spree::Imports::ProcessGroupJob, type: :job do
  let(:store) { @default_store }

  let!(:import) do
    create(:import, owner: store, type: 'Spree::Imports::Products', status: :processing,
           processing_groups_count: 1, completed_groups_count: 0)
  end

  let!(:row) do
    create(:import_row, import: import, row_number: 1, status: :pending,
           data: { 'slug' => 'test-product', 'sku' => 'SKU1', 'name' => 'Test Product', 'price' => '9.99' }.to_json)
  end

  before do
    allow_any_instance_of(Spree::Import).to receive(:csv_headers).and_return(['slug', 'sku', 'name', 'price'])
    import.create_mappings
  end

  it 'sets Spree::Current.store from the import' do
    described_class.perform_now(import.id, [row.id])

    expect(Spree::Current.store).to eq(store)
  end

  it 'creates the product and completes the import' do
    expect {
      described_class.perform_now(import.id, [row.id])
    }.to change(Spree::Product, :count).by(1)

    row.reload
    expect(row.status).to eq('completed')
    expect(row.item).to be_a(Spree::Product)
    expect(row.item.name).to eq('Test Product')
    expect(row.item.sku).to eq('SKU1')

    import.reload
    expect(import.completed_groups_count).to eq(1)
    expect(import.status).to eq('completed')
  end

  context 'group-level events', events: true do
    before do
      Spree::Events.reset!
    end

    after do
      Spree::Events.reset!
    end

    it 'publishes one product event per group instead of per-record lifecycle noise' do
      published = Hash.new(0)
      %w[product.created product.updated variant.created price.created].each do |name|
        Spree::Events.subscribe(name, async: false) { published[name] += 1 }
      end
      Spree::Events.activate!

      described_class.perform_now(import.id, [row.id])

      expect(published['product.created']).to eq(1)
      expect(published['variant.created']).to eq(0)
      expect(published['price.created']).to eq(0)
      expect(published['product.updated']).to eq(0)
    end

    it 'publishes product.updated when the product existed before this run' do
      described_class.perform_now(import.id, [row.id])
      row.reload.update_columns(status: 'pending')
      import.update_columns(status: 'processing', completed_groups_count: 0)

      published = Hash.new(0)
      %w[product.created product.updated].each do |name|
        Spree::Events.subscribe(name, async: false) { published[name] += 1 }
      end
      Spree::Events.activate!

      described_class.perform_now(import.id, [row.id])

      expect(published['product.created']).to eq(0)
      expect(published['product.updated']).to eq(1)
    end
  end

  it 'does not complete import when other groups still have pending rows' do
    # A second group's rows exist but haven't been processed yet; this group finishing
    # its own rows must not flip the import to completed.
    create(:import_row, import: import, row_number: 2, status: :pending,
           data: { 'slug' => 'other-product', 'sku' => 'SKU2', 'name' => 'Other', 'price' => '9.99' }.to_json)
    import.update_columns(processing_groups_count: 2)

    described_class.perform_now(import.id, [row.id])

    import.reload
    expect(import.completed_groups_count).to eq(1)
    expect(import.status).to eq('processing')
  end

  context 'when a row fails' do
    before do
      allow_any_instance_of(Spree::Imports::RowProcessors::ProductVariant).to receive(:process!).and_raise(StandardError, 'something went wrong')
    end

    it 'marks the row as failed and continues' do
      described_class.perform_now(import.id, [row.id])

      row.reload
      expect(row.status).to eq('failed')
      expect(row.validation_errors).to eq('something went wrong')

      # Import still completes (single group)
      expect(import.reload.status).to eq('completed')
    end
  end

  context 'when a row in the passed batch is already completed (job retry)' do
    # Simulates a Sidekiq retry of the group job where some rows finished on the
    # prior attempt — those must not be reprocessed and duplicate side effects.
    let!(:completed_row) do
      create(:import_row, import: import, row_number: 2, status: :completed,
             data: { 'slug' => 'already-done', 'sku' => 'DONE', 'name' => 'Already Done', 'price' => '1.00' }.to_json)
    end

    it 'reprocesses pending/failed rows and skips the completed row' do
      expect {
        described_class.perform_now(import.id, [row.id, completed_row.id])
      }.to change(Spree::Product, :count).by(1) # only the pending row creates a product; completed row is skipped

      expect(row.reload.status).to eq('completed')
      expect(completed_row.reload.status).to eq('completed')
    end
  end

  context 'when the job is retried after all its rows already finished' do
    # Status guard must prevent re-completing an import that finished on the prior
    # attempt — otherwise a transient failure inside check_import_completion's
    # post-increment side effects would emit duplicate complete! transitions on retry.
    before do
      row.update_columns(status: 'completed')
      import.update_columns(status: 'completed', completed_groups_count: 1, processing_groups_count: 1)
    end

    it 'is a no-op for completed imports' do
      expect {
        described_class.perform_now(import.id, [row.id])
      }.not_to change { [import.reload.status, row.reload.status] }
    end
  end

  context 'when a sibling row is orphaned in processing (worker killed)' do
    # A row whose worker died (OOM, SIGKILL, deploy without graceful drain) stays
    # in `processing` indefinitely. Once it's been there longer than the stall window,
    # it must not block the import from completing — otherwise a dead worker
    # permanently jams every import that lost a row.
    let!(:orphaned_row) do
      create(:import_row, import: import, row_number: 2, status: :processing,
             data: { 'slug' => 'orphan', 'sku' => 'ORPHAN', 'name' => 'Orphan', 'price' => '1.00' }.to_json)
    end

    before do
      orphaned_row.update_columns(updated_at: (Spree::ImportRow::STALLED_PROCESSING_AFTER + 5.minutes).ago)
      import.update_columns(processing_groups_count: 2, completed_groups_count: 1)
    end

    it 'completes the import despite the stalled row' do
      described_class.perform_now(import.id, [row.id])

      expect(import.reload.status).to eq('completed')
      expect(orphaned_row.reload.status).to eq('processing') # left alone for operator review
    end
  end

  context 'when a sibling row is still actively processing' do
    let!(:active_row) do
      create(:import_row, import: import, row_number: 2, status: :processing,
             data: { 'slug' => 'active', 'sku' => 'ACTIVE', 'name' => 'Active', 'price' => '1.00' }.to_json)
    end

    before do
      import.update_columns(processing_groups_count: 2, completed_groups_count: 1)
    end

    it 'does not complete the import while a live worker is still on a row' do
      described_class.perform_now(import.id, [row.id])

      expect(import.reload.status).to eq('processing')
    end
  end

  context 'with product + variant rows in a group' do
    let!(:variant_row) do
      create(:import_row, import: import, row_number: 2, status: :pending,
             data: { 'slug' => 'test-product', 'sku' => 'SKU2', 'price' => '19.99', 'option1_name' => 'Color', 'option1_value' => 'Red' }.to_json)
    end

    before do
      allow_any_instance_of(Spree::Import).to receive(:csv_headers).and_return(['slug', 'sku', 'name', 'price', 'option1_name', 'option1_value'])
      import.mappings.destroy_all
      import.create_mappings
    end

    it 'creates product and variant in row_number order' do
      expect {
        described_class.perform_now(import.id, [variant_row.id, row.id])
      }.to change(Spree::Product, :count).by(1)

      expect(row.reload.status).to eq('completed')
      expect(variant_row.reload.status).to eq('completed')

      product = row.item
      expect(product.name).to eq('Test Product')
      expect(variant_row.item).to be_a(Spree::Variant)
      expect(variant_row.item.product).to eq(product)
      expect(variant_row.item.sku).to eq('SKU2')
    end
  end

  describe 'large import (bulk_process!)' do
    before do
      allow_any_instance_of(Spree::Import).to receive(:large_import?).and_return(true)
    end

    it 'creates the product via bulk_process!' do
      expect {
        described_class.perform_now(import.id, [row.id])
      }.to change(Spree::Product, :count).by(1)

      row.reload
      expect(row.status).to eq('completed')
      expect(row.item).to be_a(Spree::Product)
      expect(row.item.name).to eq('Test Product')
      expect(row.item.sku).to eq('SKU1')
    end

    context 'with product + variant rows' do
      let!(:variant_row) do
        create(:import_row, import: import, row_number: 2, status: :pending,
               data: { 'slug' => 'test-product', 'sku' => 'SKU2', 'price' => '19.99', 'option1_name' => 'Color', 'option1_value' => 'Red' }.to_json)
      end

      before do
        allow_any_instance_of(Spree::Import).to receive(:csv_headers).and_return(['slug', 'sku', 'name', 'price', 'option1_name', 'option1_value'])
        import.mappings.destroy_all
        import.create_mappings
      end

      it 'creates product and variant via bulk_process!' do
        expect {
          described_class.perform_now(import.id, [row.id, variant_row.id])
        }.to change(Spree::Product, :count).by(1)
         .and change(Spree::Variant, :count).by(1)

        row.reload
        variant_row.reload
        expect(row.status).to eq('completed')
        expect(variant_row.status).to eq('completed')

        product = row.item
        expect(product.name).to eq('Test Product')
        expect(variant_row.item.product).to eq(product)
        expect(variant_row.item.sku).to eq('SKU2')
      end
    end

    it 'disables events during processing' do
      events_were_disabled = false

      original_bulk_process = Spree::ImportRow.instance_method(:bulk_process!)
      allow_any_instance_of(Spree::ImportRow).to receive(:bulk_process!) do |row_instance, **kwargs|
        events_were_disabled = !Spree::Events.enabled?
        original_bulk_process.bind_call(row_instance, **kwargs)
      end

      described_class.perform_now(import.id, [row.id])

      expect(events_were_disabled).to be true
      expect(row.reload.status).to eq('completed')
    end

    it 'publishes import.progress every 10 groups' do
      # Need at least one row outside this group still pending, otherwise the import
      # finishes and the progress branch never fires.
      create(:import_row, import: import, row_number: 2, status: :pending,
             data: { 'slug' => 'other-product', 'sku' => 'SKU9', 'name' => 'Other', 'price' => '1.00' }.to_json)
      import.update_columns(processing_groups_count: 20, completed_groups_count: 9)

      expect_any_instance_of(Spree::Import).to receive(:publish_event).with('import.progress')

      described_class.perform_now(import.id, [row.id])
    end

    it 'does not publish progress on non-10th group' do
      create(:import_row, import: import, row_number: 2, status: :pending,
             data: { 'slug' => 'other-product', 'sku' => 'SKU9', 'name' => 'Other', 'price' => '1.00' }.to_json)
      import.update_columns(processing_groups_count: 20, completed_groups_count: 7)

      expect_any_instance_of(Spree::Import).not_to receive(:publish_event).with('import.progress')

      described_class.perform_now(import.id, [row.id])
    end
  end

  describe 'atomic completion tracking' do
    it 'uses atomic SQL increment for completed_groups_count' do
      # Leave another row pending so the import doesn't finalize on this run; we want
      # to assert on the in-flight counter, not the final state.
      create(:import_row, import: import, row_number: 2, status: :pending,
             data: { 'slug' => 'other-product', 'sku' => 'SKUX', 'name' => 'Other', 'price' => '1.00' }.to_json)
      import.update_columns(processing_groups_count: 2, completed_groups_count: 0)

      described_class.perform_now(import.id, [row.id])

      expect(import.reload.completed_groups_count).to eq(1)
      expect(import.status).to eq('processing')
    end
  end
end
