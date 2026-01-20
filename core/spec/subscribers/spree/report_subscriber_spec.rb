# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ReportSubscriber do
  describe '.subscription_patterns' do
    it 'subscribes to report.created event' do
      expect(described_class.subscription_patterns).to include('report.created')
    end
  end

  describe '.event_handlers' do
    it 'routes report.created to generate_report_async' do
      expect(described_class.event_handlers['report.created']).to eq(:generate_report_async)
    end
  end

  describe '#generate_report_async' do
    let(:store) { @default_store }
    let(:user) { create(:admin_user) }
    let(:subscriber) { described_class.new }

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
      event = Spree::Event.new(
        name: 'report.created',
        payload: { 'id' => report.id }
      )

      expect(Spree::Reports::GenerateJob).to receive(:perform_later).with(report.id)

      subscriber.generate_report_async(event)
    end

    it 'does not call job if report_id is missing' do
      event = Spree::Event.new(
        name: 'report.created',
        payload: {}
      )

      expect(Spree::Reports::GenerateJob).not_to receive(:perform_later)

      subscriber.generate_report_async(event)
    end
  end
end
