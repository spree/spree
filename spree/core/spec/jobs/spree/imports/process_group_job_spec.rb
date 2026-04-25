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
    expect(row.item).to be_a(Spree::Variant)
    expect(row.item.product.name).to eq('Test Product')
    expect(row.item.sku).to eq('SKU1')

    import.reload
    expect(import.completed_groups_count).to eq(1)
    expect(import.status).to eq('completed')
  end

  it 'does not complete import when other groups are still pending' do
    import.update_columns(processing_groups_count: 3)

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

      product = row.item.product
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
      expect(row.item).to be_a(Spree::Variant)
      expect(row.item.product.name).to eq('Test Product')
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
         .and change(Spree::Variant, :count).by(2) # master + variant

        row.reload
        variant_row.reload
        expect(row.status).to eq('completed')
        expect(variant_row.status).to eq('completed')

        product = row.item.product
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
      import.update_columns(processing_groups_count: 20, completed_groups_count: 9)

      expect_any_instance_of(Spree::Import).to receive(:publish_event).with('import.progress')

      described_class.perform_now(import.id, [row.id])
    end

    it 'does not publish progress on non-10th group' do
      import.update_columns(processing_groups_count: 20, completed_groups_count: 7)

      expect_any_instance_of(Spree::Import).not_to receive(:publish_event).with('import.progress')

      described_class.perform_now(import.id, [row.id])
    end
  end

  describe 'atomic completion tracking' do
    it 'uses atomic SQL increment for completed_groups_count' do
      import.update_columns(processing_groups_count: 2, completed_groups_count: 0)

      described_class.perform_now(import.id, [row.id])

      expect(import.reload.completed_groups_count).to eq(1)
      expect(import.status).to eq('processing')
    end
  end
end
