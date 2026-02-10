require 'spec_helper'

RSpec.describe Spree::Report, type: :model do
  it_behaves_like 'lifecycle events', factory: :report

  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:report) { build(:report, store: store, user: user) }

  describe '#human_name' do
    before { report.save! }

    it 'returns formatted name with store, dates and report type' do
      expected_name = [
        'Sales total',
        store.name,
        report.date_from.strftime('%Y-%m-%d'),
        report.date_to.strftime('%Y-%m-%d')
      ].join(' - ')

      expect(report.human_name).to eq(expected_name)
    end
  end

  describe '#event_serializer_class' do
    it 'returns the correct serializer class' do
      expect(report.event_serializer_class).to eq(Spree::Events::ReportSerializer)
    end
  end

  describe '#generate' do
    before { report.save! }

    it 'generates CSV file and attaches it' do
      expect { report.generate }.to change(report.attachment, :attached?).from(false).to(true)
    end

    it 'sends report done email when user is present' do
      expect { report.generate }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    context 'when user is not present' do
      let(:report) { build(:report, store: store, user: nil) }

      it 'does not send report done email' do
        expect { report.generate }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end
  end

  describe '#attachment_file_name' do
    before { report.save! }

    it 'returns the correct file name format' do
      expect(report.attachment_file_name).to match(/#{store.code}-salestotal-report-\d{14}\.csv/)
    end
  end

  describe 'callbacks' do
    describe 'after_initialize' do
      let(:new_report) { Spree::Report.new(store: store) }

      it 'sets default currency from store' do
        expect(new_report.currency).to eq(store.default_currency)
      end

      it 'sets default date range' do
        expect(new_report.date_from).to be_within(1.day).of(1.month.ago)
        expect(new_report.date_to).to be_within(1.day).of(Time.current)
      end
    end
  end
end
