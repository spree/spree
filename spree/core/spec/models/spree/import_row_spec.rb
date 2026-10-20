require 'spec_helper'

RSpec.describe Spree::ImportRow, :job, type: :model do
  let(:store) { @default_store }
  let(:import) { create(:product_import, store: store) }
  let(:import_row) { build(:import_row, import: import, row_number: 1, data: '{"slug": "test-product", "name": "Test Product", "price": "10.00"}') }

  let(:csv_content) { File.read(File.join(Spree::Core::Engine.root, 'spec/fixtures/files', 'products_import.csv')) }

  before do
    # Stub the file content reading since ActiveStorage doesn't persist files properly in transactional tests
    allow(import).to receive(:attachment_file_content).and_return(csv_content)
  end

  describe 'status' do
    before { import_row.save! }

    it 'rejects an unknown status' do
      import_row.status = 'nonsense'
      expect(import_row).not_to be_valid
    end
  end

  describe 'Scopes' do
    let!(:pending_row) { create(:import_row, import: import, status: 'pending') }
    let!(:failed_row) { create(:import_row, import: import, status: 'failed') }
    let!(:completed_row) { create(:import_row, import: import, status: 'completed') }
    let!(:processing_row) { create(:import_row, import: import, status: 'processing') }

    describe '.pending_and_failed' do
      it 'returns pending and failed rows' do
        expect(described_class.pending_and_failed).to include(pending_row, failed_row)
        expect(described_class.pending_and_failed).not_to include(completed_row, processing_row)
      end
    end

    describe '.processed' do
      it 'returns completed and failed rows' do
        expect(described_class.processed).to include(completed_row, failed_row)
        expect(described_class.processed).not_to include(pending_row, processing_row)
      end
    end
  end

  describe '#data_json' do
    context 'with valid JSON data' do
      it 'returns parsed JSON' do
        expect(import_row.data_json).to eq({
          'slug' => 'test-product',
          'name' => 'Test Product',
          'price' => '10.00'
        })
      end

      it 'memoizes the result' do
        allow(JSON).to receive(:parse).and_call_original
        2.times { import_row.data_json }

        expect(JSON).to have_received(:parse).with(import_row.data).once
      end
    end

    context 'with invalid JSON data' do
      before { import_row.data = 'invalid json' }

      it 'returns empty hash' do
        expect(import_row.data_json).to eq({})
      end
    end
  end

  describe '#to_schema_hash' do
    before do
      Spree.import_start_mapping_workflow.call(import: import)
    end

    it 'returns attributes mapped to schema fields' do
      schema_hash = import_row.to_schema_hash
      expect(schema_hash).to be_a(Hash)
      expect(schema_hash).to have_key('slug')
    end
  end

  describe '#attribute_by_schema_field' do
    before do
      Spree.import_start_mapping_workflow.call(import: import)
    end

    it 'returns the mapped attribute value' do
      result = import_row.attribute_by_schema_field('slug')
      expect(result).to eq('test-product')
    end
  end

  describe '#process!' do
    let(:processor) { double('processor') }
    let(:product) { create(:product) }

    before do
      import_row.save!
      allow(import).to receive(:row_processor_class).and_return(double(new: processor))
    end

    context 'when processing succeeds' do
      before do
        allow(processor).to receive(:process!).and_return(product)
      end

      it 'transitions to processing then completed' do
        expect { import_row.process! }.to change(import_row, :status).from('pending').to('completed')
      end

      it 'sets the item' do
        import_row.process!
        expect(import_row.item).to eq(product)
      end
    end

    context 'when processing fails' do
      let(:error_message) { 'Processing failed' }

      before do
        allow(processor).to receive(:process!).and_raise(StandardError, error_message)
      end

      it 'transitions to failed' do
        expect { import_row.process! }.to change(import_row, :status).from('pending').to('failed')
      end

      it 'publishes import_row.failed', events: true do
        allow(import_row).to receive(:publish_event).with(anything)
        expect(import_row).to receive(:publish_event).with('import_row.failed')

        import_row.process!
      end

      it 'sets validation errors' do
        import_row.process!
        expect(import_row.validation_errors).to eq(error_message)
      end

      it 'reports the error to Rails.error' do
        expect(Rails.error).to receive(:report).with(an_instance_of(StandardError), handled: true, context: { import_row_id: import_row.id }, source: 'spree.core')
        import_row.process!
      end
    end
  end
end
