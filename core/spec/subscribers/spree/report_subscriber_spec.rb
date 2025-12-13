# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ReportSubscriber do
  before { Spree::Events.activate! }
  after { Spree::Events.reset! }

  describe '.subscription_patterns' do
    it 'subscribes to report.create event' do
      expect(described_class.subscription_patterns).to include('report.create')
    end
  end

  describe '.event_handlers' do
    it 'routes report.create to generate_report_async' do
      expect(described_class.event_handlers['report.create']).to eq(:generate_report_async)
    end
  end

  describe '#generate_report_async' do
    let(:store) { create(:store) }
    let(:user) { create(:admin_user) }

    it 'triggers report generation job when report is created' do
      expect(Spree::Reports::GenerateJob).to receive(:perform_later).with(kind_of(Integer))

      Spree::Reports::SalesTotal.create!(
        store: store,
        user: user,
        date_from: 1.month.ago,
        date_to: Time.current,
        currency: store.default_currency
      )
    end

    context 'with event payload' do
      let(:report) do
        create(:report,
          store: store,
          user: user,
          date_from: 1.month.ago,
          date_to: Time.current,
          currency: store.default_currency
        )
      end

      it 'extracts report_id from event payload' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'report.create',
          payload: { 'id' => report.id }
        )

        expect(Spree::Reports::GenerateJob).to receive(:perform_later).with(report.id)

        subscriber.generate_report_async(event)
      end

      it 'does not call job if report_id is missing' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'report.create',
          payload: {}
        )

        expect(Spree::Reports::GenerateJob).not_to receive(:perform_later)

        subscriber.generate_report_async(event)
      end
    end
  end
end
