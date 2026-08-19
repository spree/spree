require 'spec_helper'
require 'active_job/continuation/test_helper'

RSpec.describe Spree::Imports::ProcessJob, type: :job do
  let(:user) { create(:admin_user) }
  let(:store) { @default_store }

  describe 'row creation from the CSV attachment' do
    let(:csv_content) do
      <<~CSV
        slug,sku,name,price,option1_name,option1_value
        denim-shirt,SKU1,Denim Shirt,9.99
        denim-shirt,SKU2,,19.99,Color,Red
      CSV
    end

    let!(:import) do
      create(:import, user: user, owner: store, type: 'Spree::Imports::Products', status: :completed_mapping)
    end

    before do
      import.attachment.attach(io: StringIO.new(csv_content), filename: 'products.csv', content_type: 'text/csv')
    end

    it 'creates import rows from the CSV file' do
      expect {
        described_class.perform_now(import.id)
      }.to change { Spree::ImportRow.where(import: import).count }.by(2)

      first_row = import.rows.find_by(row_number: 1)
      expect(first_row.data).to eq({ 'slug' => 'denim-shirt', 'sku' => 'SKU1', 'name' => 'Denim Shirt', 'price' => '9.99', 'option1_name' => nil, 'option1_value' => nil }.to_json)
      expect(first_row.status).to eq('pending')

      second_row = import.rows.find_by(row_number: 2)
      expect(second_row.data).to eq({ 'slug' => 'denim-shirt', 'sku' => 'SKU2', 'name' => nil, 'price' => '19.99', 'option1_name' => 'Color', 'option1_value' => 'Red' }.to_json)
      expect(second_row.status).to eq('pending')
    end

    it 'transitions the import to processing and dispatches groups in the same run' do
      expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later).at_least(:once)

      expect { described_class.perform_now(import.id) }
        .to change { import.reload.status }.from('completed_mapping').to('processing')

      expect(import.reload.processing_groups_count).to be > 0
    end

    it 'persists rows count' do
      expect { described_class.perform_now(import.id) }.to change { import.reload.rows_count }.from(0).to(2)
    end

    context 'when CSV is malformed' do
      let(:csv_content) { "bad data \x80" }

      it 'sets processing_errors and fails the import' do
        described_class.perform_now(import.id)

        import.reload
        expect(import.status).to eq('failed')
        expect(import.processing_errors).to be_present
      end
    end

    describe 'interruption and resume' do
      include ActiveJob::Continuation::TestHelper

      around do |example|
        original = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = :test
        example.run
      ensure
        ActiveJob::Base.queue_adapter = original
      end

      before { stub_const('Spree::Imports::ProcessJob::ROW_BATCH_SIZE', 1) }

      it 'resumes row creation from the cursor after an interruption' do
        described_class.perform_later(import.id)

        interrupt_job_during_step(described_class, :create_rows, cursor: 2) { perform_enqueued_jobs }
        expect(import.rows.count).to eq(1)
        expect(import.reload.status).to eq('processing')

        perform_enqueued_jobs

        expect(import.rows.order(:row_number).pluck(:row_number)).to eq([1, 2])
        expect(import.reload.rows_count).to eq(2)
        expect(import.processing_groups_count).to be > 0
      end
    end
  end

  describe 'group dispatch (skip_row_creation: true)' do
    describe 'grouped import (Products)' do
      let!(:import) do
        create(:import, owner: store, type: 'Spree::Imports::Products', status: :processing)
      end

      before do
        allow_any_instance_of(Spree::Import).to receive(:csv_headers).and_return(['slug', 'sku', 'name', 'price', 'option1_name', 'option1_value'])
        seed_import_mappings(import)
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

        described_class.perform_now(import.id, skip_row_creation: true)

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

        described_class.perform_now(import.id, skip_row_creation: true)

        expect(import.reload.processing_groups_count).to eq(2)
      end

      context 'with failed rows' do
        before { variant_row.update_columns(status: 'failed') }

        it 'includes failed rows for reprocessing' do
          expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
            .with(import.id, [product_row.id, variant_row.id])
          expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
            .with(import.id, [other_product_row.id])

          described_class.perform_now(import.id, skip_row_creation: true)
        end
      end

      context 'with rows missing the group value' do
        before { stub_const('Spree::Imports::ProcessJob::GROUP_BATCH_SIZE', 2) }

        let!(:ungrouped_rows) do
          3.times.map do |i|
            create(:import_row, import: import, row_number: 4 + i, status: :pending,
                                data: { 'sku' => "LONE#{i}", 'name' => "Lone #{i}", 'price' => '5.00' }.to_json)
          end
        end

        it 'splits ungrouped rows into bounded batches instead of one unbounded job' do
          expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
            .with(import.id, [product_row.id, variant_row.id])
          expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
            .with(import.id, [other_product_row.id])
          expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
            .with(import.id, ungrouped_rows.first(2).map(&:id))
          expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later)
            .with(import.id, [ungrouped_rows.last.id])

          described_class.perform_now(import.id, skip_row_creation: true)

          expect(import.reload.processing_groups_count).to eq(4)
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

        described_class.perform_now(import.id, skip_row_creation: true)

        expect(import.reload.processing_groups_count).to eq(1)
      end

      context 'with more rows than GROUP_BATCH_SIZE' do
        before { stub_const('Spree::Imports::ProcessJob::GROUP_BATCH_SIZE', 2) }

        it 'dispatches multiple batch jobs' do
          expect(Spree::Imports::ProcessGroupJob).to receive(:perform_later).exactly(3).times

          described_class.perform_now(import.id, skip_row_creation: true)

          expect(import.reload.processing_groups_count).to eq(3)
        end
      end
    end
  end
end
