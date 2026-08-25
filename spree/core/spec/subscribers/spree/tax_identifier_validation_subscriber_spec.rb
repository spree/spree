# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::TaxIdentifierValidationSubscriber do
  include ActiveJob::TestHelper

  let(:store) { @default_store }
  let(:customer) { create(:customer) }

  around do |example|
    Spree.tax_identifier_validators['eu_vat'] = 'Spree::TaxIdentifiers::Validator::Base'
    example.run
  ensure
    Spree.tax_identifier_validators.delete('eu_vat')
  end

  describe '.subscription_patterns' do
    it 'subscribes to the number-changed event' do
      expect(described_class.subscription_patterns).to include('tax_identifier.number_changed')
    end
  end

  describe '#call' do
    let(:identifier) { create(:tax_identifier, owner: customer, kind: 'eu_vat') }
    let(:event) { Spree::Event.new(name: 'tax_identifier.number_changed', payload: { 'id' => identifier.prefixed_id }) }

    it 'queues the registry check' do
      expect { described_class.new.call(event) }.to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
    end

    it 'does nothing for a kind nothing here can check' do
      identifier.update_columns(kind: 'au_abn')

      expect { described_class.new.call(event) }.not_to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
    end

    # A placed order's number is a snapshot: re-checking it could contradict
    # what the order was taxed under.
    it 'does nothing for an order snapshot' do
      snapshot = create(:tax_identifier, :on_order, owner: create(:order, store: store), kind: 'eu_vat')
      snapshot_event = Spree::Event.new(name: 'tax_identifier.number_changed', payload: { 'id' => snapshot.prefixed_id })

      expect { described_class.new.call(snapshot_event) }.not_to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
    end

    it 'ignores a row deleted between publish and handling' do
      missing = Spree::Event.new(name: 'tax_identifier.number_changed', payload: { 'id' => 'txi_missing' })

      expect { described_class.new.call(missing) }.not_to raise_error
    end
  end
end
