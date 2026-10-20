require 'spec_helper'

RSpec.describe Spree::Events::Catalog do
  subject(:catalog) { described_class.new }

  describe '#declare' do
    it 'prefixes a bare action with the model event prefix' do
      catalog.declare(Spree::Order, :placed)

      expect(catalog.find('order.placed')).to have_attributes(name: 'order.placed', model_name: 'Spree::Order', group: 'order')
    end

    it 'keeps a dotted name as given' do
      catalog.declare(Spree::Fulfillment, 'shipment.shipped', deprecated_alias_of: 'fulfillment.fulfilled')

      entry = catalog.find('shipment.shipped')
      expect(entry).to be_deprecated
      expect(entry.deprecated_alias_of).to eq('fulfillment.fulfilled')
    end

    it 'replaces an earlier declaration of the same event' do
      catalog.declare(Spree::Order, :placed)
      catalog.declare(Spree::Order, :placed, deprecated_alias_of: 'order.completed')

      expect(catalog.find('order.placed')).to be_deprecated
    end
  end

  describe '#credential?' do
    it 'is true for an event declared with the permission it needs' do
      catalog.declare(Spree::Customer, 'customer.password_reset_requested', credential: 'write_customers')

      expect(catalog.credential?('customer.password_reset_requested')).to be(true)
      expect(catalog.find('customer.password_reset_requested').credential_permission).to eq('write_customers')
      expect(catalog.credential?('order.placed')).to be(false)
    end
  end

  describe '#webhook?' do
    it 'is true for an event declared without `webhook: false`, and for an undeclared one' do
      catalog.instance_variable_set(:@loaded, true)
      catalog.declare(Spree::Order, :placed)

      expect(catalog.webhook?('order.placed')).to be(true)
      expect(catalog.webhook?('order.teleported')).to be(true)
    end

    # Where classes load lazily, the process delivering webhooks may not have
    # loaded the model that declares an event `webhook: false` yet.
    it 'loads every model before letting an unknown event through' do
      allow(catalog).to receive(:load!).and_wrap_original do |original|
        catalog.declare(Spree::AdminUser, 'admin_user.password_reset_requested', webhook: false)
        original.call
      end

      expect(catalog.webhook?('admin_user.password_reset_requested')).to be(false)
    end
  end

  describe '#verify_declared!' do
    before { catalog.instance_variable_set(:@loaded, true) }

    it 'passes for a declared event' do
      catalog.declare(Spree::Order, :placed)

      expect { catalog.verify_declared!('order.placed') }.not_to raise_error
    end

    it 'raises for an undeclared event in test' do
      expect { catalog.verify_declared!('order.teleported') }.to raise_error(Spree::Events::UndeclaredEventError, /order\.teleported/)
    end

    it 'only warns when raising is switched off, as in production' do
      Spree::Events.raise_on_undeclared_events = false
      allow(Rails.logger).to receive(:warn)

      expect { catalog.verify_declared!('order.teleported') }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with(/order\.teleported/)
    ensure
      Spree::Events.raise_on_undeclared_events = nil
    end
  end

  describe 'the core catalog' do
    let(:entries) { Spree::Events.catalog.all }

    it 'declares the lifecycle and custom events core publishes' do
      expect(entries.map(&:name)).to include('order.created', 'order.placed', 'fulfillment.fulfilled', 'customer.anonymized')
    end

    it 'marks the customer password reset request as a credential event' do
      expect(Spree::Events.catalog.credential_events.map(&:name)).to eq(['customer.password_reset_requested'])
    end

    it 'never forwards staff or seller password reset requests to webhooks' do
      expect(Spree::Events.catalog.webhook?('admin_user.password_reset_requested')).to be(false)
      expect(Spree::Events.catalog.webhook?('seller_user.password_reset_requested')).to be(false)
      expect(Spree::Events.catalog.webhook_events.map(&:name)).not_to include('admin_user.password_reset_requested')
    end
  end
end
