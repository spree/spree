# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::ImportRowSubscriber do
  describe '.subscription_patterns' do
    it 'subscribes to import_row.completed event' do
      expect(described_class.subscription_patterns).to include('import_row.completed')
    end

    it 'subscribes to import_row.failed event' do
      expect(described_class.subscription_patterns).to include('import_row.failed')
    end
  end

  describe '.event_handlers' do
    it 'routes import_row.completed to update_import_view' do
      expect(described_class.event_handlers['import_row.completed']).to eq(:update_import_view)
    end

    it 'routes import_row.failed to update_import_view' do
      expect(described_class.event_handlers['import_row.failed']).to eq(:update_import_view)
    end
  end

  describe '#update_import_view' do
    let(:store) { @default_store }
    let(:user) { create(:admin_user) }
    let(:import) { create(:import, owner: store, user: user) }
    let(:import_row) { create(:import_row, import: import) }

    context 'with valid import_row_id' do
      it 'updates the import view' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'import_row.completed',
          payload: { 'id' => import_row.id }
        )

        expect(subscriber).to receive(:add_row_to_import_view).with(kind_of(Spree::ImportRow))
        expect(subscriber).to receive(:update_footer_in_import_view).with(kind_of(Spree::ImportRow))

        subscriber.update_import_view(event)
      end
    end

    context 'with missing import_row_id' do
      it 'does nothing' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'import_row.completed',
          payload: {}
        )

        expect(subscriber).not_to receive(:add_row_to_import_view)
        expect(subscriber).not_to receive(:update_footer_in_import_view)

        subscriber.update_import_view(event)
      end
    end

    context 'with non-existent import_row_id' do
      it 'does nothing' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'import_row.completed',
          payload: { 'id' => -999 }
        )

        expect(subscriber).not_to receive(:add_row_to_import_view)
        expect(subscriber).not_to receive(:update_footer_in_import_view)

        subscriber.update_import_view(event)
      end
    end
  end
end
