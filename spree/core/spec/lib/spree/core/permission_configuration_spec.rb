require 'spec_helper'
require 'cancan'

RSpec.describe Spree::PermissionConfiguration do
  subject(:configuration) { described_class.new }

  describe 'default catalog' do
    it 'registers the core resources' do
      expect(configuration.resource(:orders)).to be_present
      expect(configuration.resource(:products)).to be_present
      expect(configuration.resource(:staff)).to be_present
      expect(configuration.resource(:dashboard)).to be_present
    end

    it 'yields read and write keys per resource' do
      expect(configuration.catalog_keys).to include('read_orders', 'write_orders', 'read_staff', 'write_staff')
    end

    it 'yields no write key for read-only resources' do
      expect(configuration.catalog_keys).to include('read_dashboard')
      expect(configuration.catalog_keys).not_to include('write_dashboard')
    end
  end

  describe '#register_resource' do
    it 'registers a resource with lazy subjects and yields its keys' do
      configuration.register_resource(:reviews, group: :catalog, subjects: -> { [Spree::Product] })

      expect(configuration.catalog_keys).to include('read_reviews', 'write_reviews')
      expect(configuration.resource(:reviews).subjects).to eq([Spree::Product])
      expect(configuration.resource(:reviews).group).to eq(:catalog)
    end

    it 'replaces an existing registration with the same name' do
      configuration.register_resource(:reviews, group: :catalog, subjects: [Spree::Product])
      configuration.register_resource(:reviews, group: :marketing, subjects: [Spree::Order])

      expect(configuration.resource(:reviews).group).to eq(:marketing)
    end
  end

  describe '#unregister_resource' do
    it 'removes the resource and its keys' do
      configuration.register_resource(:reviews, group: :catalog, subjects: [Spree::Product])
      configuration.unregister_resource(:reviews)

      expect(configuration.resource(:reviews)).to be_nil
      expect(configuration.catalog_keys).not_to include('read_reviews')
    end
  end

  describe '#resolve_key' do
    it 'resolves read and write keys' do
      kind, resource = configuration.resolve_key('write_orders')
      expect(kind).to eq(:write)
      expect(resource.name).to eq(:orders)

      kind, resource = configuration.resolve_key('read_gift_cards')
      expect(kind).to eq(:read)
      expect(resource.name).to eq(:gift_cards)
    end

    it 'returns nil for unknown keys' do
      expect(configuration.resolve_key('write_bogus')).to be_nil
      expect(configuration.resolve_key('read_bogus')).to be_nil
      expect(configuration.resolve_key('bogus')).to be_nil
    end

    it 'returns nil for a write key on a read-only resource' do
      expect(configuration.resolve_key('write_dashboard')).to be_nil
    end
  end

  describe '#activate_key' do
    let(:ability_class) do
      Class.new do
        include CanCan::Ability

        def initialize; end
      end
    end
    let(:ability) { ability_class.new }

    it 'grants read and admin for a read key' do
      configuration.activate_key(ability, 'read_orders')

      expect(ability.can?(:read, Spree::Order)).to be true
      expect(ability.can?(:admin, Spree::Order)).to be true
      expect(ability.can?(:update, Spree::Order)).to be false
    end

    it 'grants manage for a write key' do
      configuration.activate_key(ability, 'write_orders')

      expect(ability.can?(:manage, Spree::Order)).to be true
    end

    it 'returns false for unknown keys' do
      expect(configuration.activate_key(ability, 'write_bogus')).to be false
    end
  end

  describe '#expand_keys' do
    it 'expands write keys to include the read key' do
      expect(configuration.expand_keys(%w[write_orders])).to eq(%w[read_orders write_orders])
    end

    it 'keeps read keys as-is' do
      expect(configuration.expand_keys(%w[read_orders])).to eq(%w[read_orders])
    end

    it 'drops unknown keys' do
      expect(configuration.expand_keys(%w[read_orders bogus write_nothing])).to eq(%w[read_orders])
    end

    it 'expands write_all to the whole catalog' do
      expect(configuration.expand_keys(%w[write_all])).to eq(configuration.catalog_keys)
    end

    it 'expands read_all to every read key' do
      expanded = configuration.expand_keys(%w[read_all])

      expect(expanded).to include('read_orders', 'read_products', 'read_dashboard')
      expect(expanded.grep(/\Awrite_/)).to be_empty
    end

    it 'preserves catalog order' do
      expect(configuration.expand_keys(%w[write_products read_orders])).to eq(
        %w[read_orders read_products write_products]
      )
    end
  end

  describe '#reset!' do
    it 'restores the default catalog' do
      configuration.register_resource(:reviews, group: :catalog, subjects: [Spree::Product])
      configuration.reset!

      expect(configuration.resource(:reviews)).to be_nil
      expect(configuration.resource(:orders)).to be_present
    end
  end

  describe '#assign' do
    it 'raises with upgrade directions — permission sets were removed in 6.0' do
      expect { configuration.assign(:admin, []) }.to raise_error(
        Spree::PermissionConfiguration::PermissionSetsRemovedError, /removed in Spree 6\.0/
      )
    end
  end
end
