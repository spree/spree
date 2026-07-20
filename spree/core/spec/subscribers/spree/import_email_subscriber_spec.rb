# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ImportEmailSubscriber do
  describe '.subscription_patterns' do
    it 'subscribes to import.completed' do
      expect(described_class.subscription_patterns).to include('import.completed')
    end
  end

  describe '.event_handlers' do
    it 'routes import.completed to send_import_done_email' do
      expect(described_class.event_handlers['import.completed']).to eq(:send_import_done_email)
    end
  end

  describe '#send_import_done_email' do
    let(:store) { @default_store }
    let(:user) { create(:admin_user) }
    let(:subscriber) { described_class.new }
    let(:import) { create(:product_import, owner: store, user: user) }

    def event_for(id)
      Spree::Event.new(name: 'import.completed', payload: { 'id' => id })
    end

    it 'delivers the import done email' do
      mail = double(deliver_later: true)
      expect(Spree::ImportMailer).to receive(:import_done).with(import).and_return(mail)

      subscriber.send_import_done_email(event_for(import.prefixed_id))
    end

    it 'does nothing when the id is missing' do
      expect(Spree::ImportMailer).not_to receive(:import_done)

      subscriber.send_import_done_email(event_for(nil))
    end

    it 'does nothing when the owner is gone' do
      import.update_columns(user_id: 0)

      expect(Spree::ImportMailer).not_to receive(:import_done)

      subscriber.send_import_done_email(event_for(import.prefixed_id))
    end
  end
end
