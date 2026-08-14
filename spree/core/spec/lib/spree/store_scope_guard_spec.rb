require 'spec_helper'

RSpec.describe Spree::StoreScopeGuard do
  after { Spree::Config.store_scope_guard = nil }

  describe 'raise mode' do
    before { Spree::Config.store_scope_guard = 'raise' }

    it 'raises for a store-less query on a store-owned table inside the window' do
      expect {
        described_class.watch { Spree::Product.where(name: 'x').to_a }
      }.to raise_error(described_class::UnscopedQueryError, /spree_products/)
    end

    it 'passes a query carrying a store_id predicate' do
      expect {
        described_class.watch { Spree::Product.where(store_id: 1).to_a }
      }.not_to raise_error
    end

    it 'is not fooled by a projected store_id column without a predicate' do
      expect {
        described_class.watch { Spree::Product.select(:store_id, :name).where(name: 'x').to_a }
      }.to raise_error(described_class::UnscopedQueryError, /spree_products/)
    end

    # The suite runs on one adapter at a time, so pin the predicate matching
    # against every adapter's quoting directly — MySQL's backticks broke it
    # once while PostgreSQL and SQLite passed.
    it 'recognizes predicates under every identifier quoting style' do
      [
        %(SELECT * FROM "spree_products" WHERE "spree_products"."store_id" = 1),
        %(SELECT * FROM `spree_products` WHERE `spree_products`.`store_id` = 1),
        %(SELECT * FROM spree_products WHERE store_id = 1),
      ].each do |sql|
        expect(described_class.send(:scoped?, sql)).to be(true), "not recognized: #{sql}"
      end
    end

    # Same reasoning as above, from the other side: a null check matches
    # storeless or all-store rows rather than a store, under any quoting.
    it 'does not count store_id null checks as store scoping' do
      [
        %(SELECT * FROM "spree_products" WHERE "spree_products"."store_id" IS NULL),
        %(SELECT * FROM "spree_products" WHERE "spree_products"."store_id" IS NOT NULL),
        %(SELECT * FROM `spree_products` WHERE `spree_products`.`store_id` IS NULL),
        %(SELECT * FROM `spree_products` WHERE `spree_products`.`store_id` IS NOT NULL),
        %(SELECT * FROM spree_products WHERE store_id IS NULL),
        %(SELECT * FROM spree_products WHERE store_id IS NOT NULL),
      ].each do |sql|
        expect(described_class.send(:scoped?, sql)).to be(false), "incorrectly recognized: #{sql}"
      end
    end

    it 'passes id and foreign-key filters (ids in hand came from scoped rows)' do
      expect {
        described_class.watch { Spree::Order.where(customer_id: 1).to_a }
      }.not_to raise_error
    end

    it 'ignores tables without a store_id column' do
      expect {
        described_class.watch { Spree::Country.where(iso: 'US').to_a }
      }.not_to raise_error
    end

    it 'ignores the stores table itself' do
      expect {
        described_class.watch { Spree::Store.where(default: true).to_a }
      }.not_to raise_error
    end

    it 'is inert outside a watched window' do
      described_class.watch { Spree::Store.default } # installs the subscriber

      expect { Spree::Product.where(name: 'x').to_a }.not_to raise_error
    end

    it 'lets a deliberately global lookup opt out with skip' do
      expect {
        described_class.watch do
          described_class.skip { Spree::Product.where(name: 'x').to_a }
        end
      }.not_to raise_error
    end
  end

  # Declaring a store context arms the guard for the rest of the unit of
  # work, so jobs, webhook controllers and console scripts are covered
  # without registering each entry point.
  describe 'arming through Spree::Current.store' do
    before { Spree::Config.store_scope_guard = 'raise' }

    after { Spree::Current.reset }

    it 'guards work that declared a store, with no watch block' do
      Spree::Current.store = @default_store

      expect { Spree::Product.where(name: 'x').to_a }.
        to raise_error(described_class::UnscopedQueryError, /spree_products/)
    end

    it 'leaves work that never declared a store alone' do
      Spree::Current.reset

      expect { Spree::Product.where(name: 'x').to_a }.not_to raise_error
    end

    it 'stops guarding once the context resets, as it does between jobs' do
      Spree::Current.store = @default_store
      Spree::Current.reset

      expect { Spree::Product.where(name: 'x').to_a }.not_to raise_error
    end

    it 'still honors skip for deliberately global lookups' do
      Spree::Current.store = @default_store

      expect {
        described_class.skip { Spree::Product.where(name: 'x').to_a }
      }.not_to raise_error
    end
  end

  describe 'log mode' do
    before { Spree::Config.store_scope_guard = 'log' }

    it 'warns instead of raising' do
      expect(Rails.logger).to receive(:warn).with(/spree_products/)

      described_class.watch { Spree::Product.where(name: 'x').to_a }
    end
  end

  describe 'off mode' do
    before { Spree::Config.store_scope_guard = 'off' }

    it 'does not watch at all' do
      expect(Rails.logger).not_to receive(:warn)

      described_class.watch { Spree::Product.where(name: 'x').to_a }
    end
  end
end
