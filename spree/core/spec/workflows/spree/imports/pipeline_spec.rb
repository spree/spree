require 'spec_helper'

RSpec.describe 'Spree::Imports pipeline workflows' do
  let(:store) { Spree::Store.default }
  let(:import) { create(:product_import, store: store) }

  describe Spree::Imports::StartMapping do
    it 'moves the import into mapping and builds a mapping per schema field' do
      expect { described_class.call(import: import) }.to change { import.reload.status }.from('pending').to('mapping')
      expect(import.mappings.count).to be > 0
    end
  end

  describe Spree::Imports::CompleteMapping do
    before { Spree.import_start_mapping_workflow.call(import: import) }

    it 'accepts the mapping' do
      expect { described_class.call(import: import) }.to change { import.reload.status }.from('mapping').to('completed_mapping')
    end

    it 'enqueues row creation' do
      expect { described_class.call(import: import) }
        .to have_enqueued_job(Spree::Imports::ProcessJob).with(import.id).on_queue(Spree.queues.imports)
    end

    it 'refuses an import that is not being mapped' do
      import.update!(status: 'pending')

      result = described_class.call(import: import)

      expect(result).not_to be_success
      expect(result.error.value).to eq(:import_not_mapping)
    end
  end

  # The machine ran its callbacks inside a transaction, so an inline run had
  # to defer itself to after_all_transactions_commit. Dispatching outside the
  # transaction removes that workaround — this proves the whole pipeline still
  # runs to completion with no worker attached, which is what seeds and rake
  # tasks depend on.
  describe 'an inline run', :job do
    it 'processes every row through to a completed import' do
      import.set_preference(:inline, true)
      import.save!

      Spree.import_start_mapping_workflow.call(import: import)
      Spree.import_complete_mapping_workflow.call(import: import)

      expect(import.reload.status).to eq('completed')
      expect(import.rows.count).to be > 0
      expect(import.rows.failed.count).to eq(0)
      expect(import.rows.completed.count).to eq(import.rows.count)
    end

    context 'when a new product row has no price' do
      let(:import) do
        create(:import, store: store, type: 'Spree::Imports::Products').tap do |import|
          rows = (1..5).map { |index| "box-#{index},BOX-#{index},Box #{index},#{'12.50' unless index == 3}" }
          csv = ['slug,sku,name,price', *rows].join("\n")
          import.attachment.attach(io: StringIO.new(csv), filename: 'boxes.csv', content_type: 'text/csv')
        end
      end

      it 'fails that row, creates no product for it, and creates it when retried with a price' do
        import.set_preference(:inline, true)
        import.save!

        Spree.import_start_mapping_workflow.call(import: import)
        Spree.import_complete_mapping_workflow.call(import: import)

        expect(import.reload.status).to eq('completed')
        expect(import.rows.completed.count).to eq(4)
        failed_row = import.rows.failed.sole
        expect(failed_row.validation_errors).to start_with('price is missing')
        expect(store.products.find_by(slug: 'box-3')).to be_nil

        failed_row.update!(data: failed_row.data_json.merge('price' => '12.50').to_json)
        expect(Spree.import_retry_failed_rows_workflow.call(import: import)).to be_success

        expect(import.reload.rows.completed.count).to eq(5)
        expect(store.products.find_by!(slug: 'box-3').default_variant.price_in(store.default_market.currency).amount).to eq(BigDecimal('12.50'))
      end
    end
  end

  describe Spree::Imports::StartProcessing do
    before { import.update!(status: 'completed_mapping') }

    it 'moves the import into processing' do
      expect { described_class.call(import: import) }.to change { import.reload.status }.to('processing')
    end
  end

  describe Spree::Imports::Complete do
    before { import.update!(status: 'processing') }

    it 'completes the import' do
      expect { described_class.call(import: import) }.to change { import.reload.status }.from('processing').to('completed')
    end

    it 'touches the store, so its cache keys move with the catalog' do
      expect { described_class.call(import: import) }.to change { store.reload.updated_at }
    end

    it 'publishes import.completed', events: true do
      allow(import).to receive(:publish_event).with(anything)
      expect(import).to receive(:publish_event).with('import.completed')

      described_class.call(import: import)
    end
  end

  describe Spree::Imports::RetryFailedRows do
    before { import.update!(status: 'completed') }

    context 'with failed rows' do
      before { create(:import_row, import: import, status: 'failed') }

      it 'puts the import back to processing' do
        expect { described_class.call(import: import) }.to change { import.reload.status }.from('completed').to('processing')
      end

      it 'enqueues processing that skips row creation' do
        expect { described_class.call(import: import) }
          .to have_enqueued_job(Spree::Imports::ProcessJob).with(import.id, skip_row_creation: true)
      end
    end

    context 'without failed rows' do
      it 'refuses' do
        result = described_class.call(import: import)

        expect(result).not_to be_success
        expect(result.error.value).to eq(:import_has_no_failed_rows)
        expect(import.reload.status).to eq('completed')
      end
    end
  end
end

# The state machine guarded these transitions with `from:`; the workflows must
# keep those guards or a failed import can flip to completed and announce
# itself as done.
RSpec.describe 'Spree::Imports status guards' do
  let(:store) { Spree::Store.default }
  let(:import) { create(:product_import, store: store) }

  it 'refuses to complete an import that is not processing' do
    import.update!(status: 'failed')

    result = Spree.import_complete_workflow.call(import: import)

    expect(result).not_to be_success
    expect(result.error.value).to eq(:import_not_processing)
    expect(import.reload.status).to eq('failed')
  end

  it 'refuses to start processing before the mapping is accepted' do
    result = Spree.import_start_processing_workflow.call(import: import)

    expect(result).not_to be_success
    expect(result.error.value).to eq(:import_mapping_not_completed)
    expect(import.reload.status).to eq('pending')
  end
end
