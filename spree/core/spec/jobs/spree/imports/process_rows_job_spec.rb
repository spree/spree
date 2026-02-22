require 'spec_helper'

RSpec.describe Spree::Imports::ProcessRowsJob, type: :job do
  let(:store) { @default_store }

  let!(:import) do
    create(
      :import,
      owner: store,
      type: 'Spree::Imports::Products',
      status: :processing
    )
  end

  let!(:pending_row) do
    create(
      :import_row,
      import: import,
      row_number: 1,
      status: :pending,
      data: { 'slug' => 'test-product', 'sku' => 'SKU1', 'name' => 'Test Product', 'price' => '9.99' }.to_json
    )
  end

  let!(:failed_row) do
    create(
      :import_row,
      import: import,
      row_number: 2,
      status: :failed,
      data: { 'slug' => 'failed-product', 'sku' => 'SKU2', 'name' => 'Failed Product', 'price' => '19.99' }.to_json
    )
  end

  let!(:processed_row) do
    create(
      :import_row,
      import: import,
      row_number: 3,
      status: :completed,
      data: { 'slug' => 'processed-product', 'sku' => 'SKU3', 'name' => 'Processed Product', 'price' => '29.99' }.to_json
    )
  end

  before do
    allow(import).to receive(:csv_headers).and_return(['slug', 'sku', 'name', 'price'])
    import.create_mappings
  end

  it 'processes pending and failed rows' do
    expect {
      described_class.perform_now(import.id)
    }.to change { pending_row.reload.status }.from('pending').to('completed').and change { failed_row.reload.status }.from('failed').to('completed')
  end

  it 'marks import as complete after processing all rows' do
    expect {
      described_class.perform_now(import.id)
    }.to change { import.reload.status }.from('processing').to('completed')
  end
end
