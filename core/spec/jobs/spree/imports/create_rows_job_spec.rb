require 'spec_helper'

RSpec.describe Spree::Imports::CreateRowsJob, type: :job do
  let(:user) { create(:admin_user) }
  let(:store) { @default_store }

  let(:csv_content) do
    <<~CSV
      slug,sku,name,price,option1_name,option1_value
      denim-shirt,SKU1,Denim Shirt,9.99
      denim-shirt,SKU2,,19.99,Color,Red
    CSV
  end

  let!(:import) do
    create(
      :import,
      user: user,
      owner: store,
      type: 'Spree::Imports::Products',
      status: :completed_mapping
    )
  end

  before do
    # Attach CSV as import attachment
    import.attachment.attach(
      io: StringIO.new(csv_content),
      filename: 'products.csv',
      content_type: 'text/csv'
    )
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

  it 'transitions import to processing if not already processing' do
    expect { described_class.perform_now(import.id) }.to change { import.reload.status }.from('completed_mapping').to('processing')
  end

  it 'persists rows count' do
    expect { described_class.perform_now(import.id) }.to change { import.reload.rows_count }.from(0).to(2)
  end

  it 'enqueues process_rows_async after rows creation' do
    expect_any_instance_of(Spree::Import).to receive(:process_rows_async).once
    described_class.perform_now(import.id)
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
end
