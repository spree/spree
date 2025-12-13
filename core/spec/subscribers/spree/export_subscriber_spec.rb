# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ExportSubscriber do
  describe '.subscription_patterns' do
    it 'subscribes to export.created event' do
      expect(described_class.subscription_patterns).to include('export.created')
    end
  end

  describe '.event_handlers' do
    it 'routes export.created to generate_export_async' do
      expect(described_class.event_handlers['export.created']).to eq(:generate_export_async)
    end
  end

  describe '#generate_export_async' do
    let(:store) { create(:store) }
    let(:user) { create(:admin_user) }
    let(:subscriber) { described_class.new }
    let(:export) { create(:export, store: store, user: user) }

    it 'extracts export_id from event payload' do
      event = Spree::Event.new(
        name: 'export.created',
        payload: { 'id' => export.id }
      )

      expect(Spree::Exports::GenerateJob).to receive(:perform_later).with(export.id)

      subscriber.generate_export_async(event)
    end

    it 'does not call job if export_id is missing' do
      event = Spree::Event.new(
        name: 'export.created',
        payload: {}
      )

      expect(Spree::Exports::GenerateJob).not_to receive(:perform_later)

      subscriber.generate_export_async(event)
    end
  end
end
