require 'spec_helper'

RSpec.describe Spree::Export, :job, type: :model do
  let(:store) { create(:store, code: 'my-store', preferred_timezone: 'UTC') }
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
      it 'sets search_params to nil to avoid crashes' do
        export.search_params = '{invalid: json'
        expect { export.normalize_search_params }.not_to raise_error
        expect(export.search_params).to be_nil
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

    context "date normalization" do
      it "expands a completed_at same-day filter to cover the whole day" do
        export.update(search_params: { completed_at_gt: "2025-09-07", completed_at_lt: "2025-09-07" })
        export.normalize_search_params
        params = JSON.parse(export.search_params)

        expect(Time.iso8601(params["completed_at_gt"])).to eq(Time.zone.parse("2025-09-07 00:00:00 #{export.store.preferred_timezone}"))
        expect(Time.iso8601(params["completed_at_lt"])).to eq(Time.zone.parse("2025-09-07 23:59:59 #{export.store.preferred_timezone}"))
      end

      it "expands a created_at same-day filter to cover the whole day" do
        export.update(search_params: { created_at_gteq: "2026-01-15", created_at_lteq: "2026-01-15" })
        export.normalize_search_params
        params = JSON.parse(export.search_params)

        expect(Time.iso8601(params["created_at_gteq"])).to eq(Time.zone.parse("2026-01-15 00:00:00 #{export.store.preferred_timezone}"))
        expect(Time.iso8601(params["created_at_lteq"])).to eq(Time.zone.parse("2026-01-15 23:59:59 #{export.store.preferred_timezone}"))
      end

      it "drops invalid dates instead of crashing" do
        export.update(search_params: { completed_at_gt: "not-a-date" })
        export.normalize_search_params
        params = JSON.parse(export.search_params)

        expect(params["completed_at_gt"]).to eq("")
      end
    end
  end
end
