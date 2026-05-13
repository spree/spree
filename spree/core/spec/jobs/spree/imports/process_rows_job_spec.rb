require 'spec_helper'

RSpec.describe Spree::Imports::ProcessRowsJob, type: :job do
  let(:store) { @default_store }

  describe 'grouped import (Products)' do
    let!(:import) do
      create(:import, owner: store, type: 'Spree::Imports::Products', status: :processing)
    end

    before do
      allow_any_instance_of(Spree::Import).to receive(:csv_headers).and_return(['slug', 'sku', 'name', 'price', 'option1_name', 'option1_value'])
      import.create_mappings
    end

    let!(:product_row) do
      create(:import_row, import: import, row_number: 1, status: :pending,
             data: { 'slug' => 'denim-shirt', 'sku' => 'SKU1', 'name' => 'Denim Shirt', 'price' => '9.99' }.to_json)
    end

    let!(:variant_row) do
      create(:import_row, import: import, row_number: 2, status: :pending,
             data: { 'slug' => 'denim-shirt', 'sku' => 'SKU2', 'price' => '19.99', 'option1_name' => 'Color', 'option1_value' => 'Red' }.to_json)
    end

    let!(:other_product_row) do
      create(:import_row, import: import, row_number: 3, status: :pending,
             data: { 'slug' => 'cotton-tee', 'sku' => 'SKU3', 'name' => 'Cotton Tee', 'price' => '14.99' }.to_json)
    end

    it 'groups rows by slug and dispatches one job per product' do
      expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
        .with(import.id, [product_row.id, variant_row.id])
      expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
        .with(import.id, [other_product_row.id])

      described_class.perform_now(import.id)

      import.reload
      expect(import.processing_groups_count).to eq(2)
      expect(import.completed_groups_count).to eq(0)
    end

    it 'skips already completed rows' do
      product_row.update_columns(status: 'completed')

      expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
        .with(import.id, [variant_row.id])
      expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
        .with(import.id, [other_product_row.id])

      described_class.perform_now(import.id)

      expect(import.reload.processing_groups_count).to eq(2)
    end

    context 'with failed rows' do
      before { variant_row.update_columns(status: 'failed') }

      it 'includes failed rows for reprocessing' do
        expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
          .with(import.id, [product_row.id, variant_row.id])
        expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
          .with(import.id, [other_product_row.id])

        described_class.perform_now(import.id)
      end
    end
  end

  describe 'batched import (Customers — no group_column)' do
    let!(:import) do
      create(:import, owner: store, type: 'Spree::Imports::Customers', status: :processing)
    end

    let!(:rows) do
      5.times.map do |i|
        create(:import_row, import: import, row_number: i + 1, status: :pending,
               data: { 'email' => "user#{i}@example.com" }.to_json)
      end
    end

    it 'batches all rows into chunks and dispatches' do
      expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
        .with(import.id, rows.map(&:id))

      described_class.perform_now(import.id)

      expect(import.reload.processing_groups_count).to eq(1)
    end

    context 'with more rows than BATCH_SIZE' do
      before { stub_const('Spree::Imports::ProcessRowsJob::BATCH_SIZE', 2) }

      it 'dispatches multiple batch jobs' do
        expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later).exactly(3).times

        described_class.perform_now(import.id)

        expect(import.reload.processing_groups_count).to eq(3)
      end
    end
  end
end
