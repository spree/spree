require 'spec_helper'

RSpec.describe Spree::Export, :job, type: :model do
  it_behaves_like 'lifecycle events', factory: :product_export

  let(:store) { create(:store, code: 'my-store') }
  let(:user) { create(:admin_user) }

  let(:search_params) { nil }
  let(:export) { build(:product_export, store: store, user: user, format: 'csv', search_params: search_params) }

  describe '#event_serializer_class' do
    it 'returns the correct event serializer class' do
      expect(export.event_serializer_class).to eq(Spree::Events::ExportSerializer)
    end
  end

  describe '#model_class' do
    it 'returns the correct record class' do
      expect(export.model_class).to eq(Spree::Product)
    end
  end

  describe '#export_file_name' do
    before { export.save! }

    it 'returns the correct file name' do
      expect(export.export_file_name).to match(/products-my-store-\d{8}\d{6}\.csv/)
    end
  end

  describe '#generate' do
    it 'generates the export' do
      export.save!
      expect { export.generate }.to change(export.attachment, :attached?).from(false).to(true)

      expect(export.attachment.content_type).to eq('text/csv')
    end

    it 'sends the export done email' do
      export.save!
      expect { export.generate }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    context 'when the export type is Spree::Exports::Customers' do
      let(:export) { build(:customer_export, store: store, user: user, format: 'csv') }

      it 'generates the export' do
        export.save!
        expect { export.generate }.to change(export.attachment, :attached?).from(false).to(true)
      end
    end
  end

  describe '#records_to_export' do
    let!(:matching_products) { create_list(:product, 3, name: 'test', stores: [store]) }
    let!(:non_matching_products) { create_list(:product, 3, name: 'something else', stores: [store]) }

    context 'without search params' do
      it 'returns all products' do
        expect(export.records_to_export).to match_array(store.products)
      end
    end

    context 'with search params' do
      let(:search_params) { { name_cont: 'test' }.to_json }

      it 'returns matching products' do
        expect(export.records_to_export).to match_array(matching_products)
        expect(export.records_to_export.count).to eq(matching_products.count)
      end
    end
  end

  describe '#send_export_done_email' do
    before { export.save! }

    it 'queues the export done email' do
      expect { export.send_export_done_email }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe '#normalize_search_params' do
    let(:export) { build(:export) }

    context 'with nil search_params' do
      it 'does nothing' do
        export.search_params = nil
        expect { export.normalize_search_params }.not_to change(export, :search_params)
      end
    end

    context 'with empty search_params' do
      it 'does nothing' do
        export.search_params = ''
        expect { export.normalize_search_params }.not_to change(export, :search_params)
      end
    end

    context 'with valid JSON string' do
      let(:params) { { filters: { date: '2023-01-01' } }.to_json }

      it 'maintains the same content' do
        export.search_params = params
        export.normalize_search_params
        expect(JSON.parse(export.search_params)).to eq(JSON.parse(params))
      end

      it 'ensures valid JSON output' do
        export.search_params = params
        export.normalize_search_params
        expect { JSON.parse(export.search_params) }.not_to raise_error
      end
    end

    context 'with invalid JSON string' do
      it 'preserves the original string' do
        export.search_params = '{invalid: json'
        expect { export.normalize_search_params }.not_to raise_error
        expect(export.search_params).to eq('{invalid: json')
      end
    end

    context 'with Ruby hash input' do
      it 'converts to JSON string' do
        export.search_params = { key: 'value' }
        export.normalize_search_params
        expect(export.search_params).to eq('{"key":"value"}')
      end
    end

    context 'with pre-normalized params' do
      it 'does not double-process' do
        export.search_params = { date: Time.current }.to_json
        original = export.search_params.dup
        export.normalize_search_params
        expect(export.search_params).to eq(original)
      end
    end
  end
end
