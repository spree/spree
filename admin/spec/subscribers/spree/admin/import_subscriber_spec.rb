# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::ImportSubscriber do
  describe '.subscription_patterns' do
    it 'subscribes to import.completed event' do
      expect(described_class.subscription_patterns).to include('import.completed')
    end
  end

  describe '.event_handlers' do
    it 'routes import.completed to update_loader_in_import_view' do
      expect(described_class.event_handlers['import.completed']).to eq(:update_loader_in_import_view)
    end
  end

  describe '#update_loader_in_import_view' do
    let(:store) { @default_store }
    let(:user) { create(:admin_user) }
    let(:import) { create(:import, owner: store, user: user) }

    context 'with valid import_id' do
      it 'broadcasts update to import loader' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'import.completed',
          payload: { 'id' => import.id }
        )

        found_import = Spree::Import.find(import.id)

        if found_import.respond_to?(:broadcast_update_to)
          expect_any_instance_of(Spree::Import).to receive(:broadcast_update_to).with(
            "import_#{import.id}_loader",
            target: 'loader',
            partial: 'spree/admin/imports/loader',
            locals: { import: kind_of(Spree::Import) }
          )
        end

        subscriber.update_loader_in_import_view(event)
      end
    end

    context 'with missing import_id' do
      it 'does nothing' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'import.completed',
          payload: {}
        )

        expect_any_instance_of(Spree::Import).not_to receive(:broadcast_update_to) if Spree::Import.new.respond_to?(:broadcast_update_to)

        subscriber.update_loader_in_import_view(event)
      end
    end

    context 'with non-existent import_id' do
      it 'does nothing' do
        subscriber = described_class.new
        event = Spree::Event.new(
          name: 'import.completed',
          payload: { 'id' => -999 }
        )

        expect(Spree::Import).to receive(:find_by).with(id: -999).and_return(nil)

        subscriber.update_loader_in_import_view(event)
      end
    end
  end
end
