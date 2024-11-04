require 'spec_helper'

RSpec.describe Spree::Export, type: :model, job: true do
  let(:store) { create(:store, code: 'my-store') }
  let(:user) { create(:admin_user) }

  let(:search_params) { nil }
  let(:export) { build(:product_export, store: store, user: user, format: 'csv', search_params: search_params) }

  context 'Callbacks' do
    describe 'after_create' do
      it 'generates the export' do
        expect { export.save! }.to have_enqueued_job(Spree::Exports::GenerateJob).with(export.id)
      end
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
    before { export.save! }

    it 'generates the export' do
      expect { export.generate }.to change(export.attachment, :attached?).from(false).to(true)

      expect(export.attachment.content_type).to eq('text/csv')
    end

    it 'sends the export done email' do
      expect { export.generate }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
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
end
