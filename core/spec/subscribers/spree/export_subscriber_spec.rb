# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ExportSubscriber do
  before { Spree::Events.activate! }
  after { Spree::Events.reset! }

  describe '.subscription_patterns' do
    it 'subscribes to export.create event' do
      expect(described_class.subscription_patterns).to include('export.create')
    end
  end

  describe '.event_handlers' do
    it 'routes export.create to generate_export_async' do
      expect(described_class.event_handlers['export.create']).to eq(:generate_export_async)
    end
  end

  describe '#generate_export_async' do
    let(:store) { create(:store) }
    let(:user) { create(:admin_user) }

    it 'triggers export generation job when export is created' do
      expect(Spree::Exports::GenerateJob).to receive(:perform_later).with(kind_of(Integer))

      Spree::Exports::Products.create!(
        store: store,
        user: user
      )
    end

    context 'with event payload' do
      let(:export) { create(:export, store: store, user: user) }

      it 'extracts export_id from event payload' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'export.create',
          payload: { 'id' => export.id }
        )

        expect(Spree::Exports::GenerateJob).to receive(:perform_later).with(export.id)

        subscriber.generate_export_async(event)
      end

      it 'does not call job if export_id is missing' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'export.create',
          payload: {}
        )

        expect(Spree::Exports::GenerateJob).not_to receive(:perform_later)

        subscriber.generate_export_async(event)
      end
    end
  end
end
