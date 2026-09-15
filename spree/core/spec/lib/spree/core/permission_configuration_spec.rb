require 'spec_helper'
require 'cancan'

RSpec.describe Spree::PermissionConfiguration do
  subject(:configuration) { described_class.new }

  describe 'default catalog' do
    it 'registers the core resources' do
      expect(configuration.scope(:orders)).to be_present
      expect(configuration.scope(:products)).to be_present
      expect(configuration.scope(:staff)).to be_present
      expect(configuration.scope(:dashboard)).to be_present
    end

    it 'yields read and write keys per resource' do
      expect(configuration.catalog_keys).to include('read_orders', 'write_orders', 'read_staff', 'write_staff')
    end

    it 'yields no write key for read-only resources' do
      expect(configuration.catalog_keys).to include('read_dashboard')
      expect(configuration.catalog_keys).not_to include('write_dashboard')
    end
  end

  # The pickers render groups in first-appearance order, so the order these
  # are registered in IS the order a merchant reads them in. Pinned here
  # because nothing else would notice a registration moving.
  describe 'group order' do
    it 'runs from what a merchant looks at most to what they set up once' do
      groups = configuration.grantable_scopes(:store).map(&:group).uniq

      expect(groups).to eq(%i[analytics orders catalog customers sellers loyalty marketing settings access])
    end

    it 'keeps running the marketplace together, apart from access' do
      expect(%i[sellers commissions payouts].map { |name| configuration.scope(name).group }).to all(eq(:sellers))
    end
  end

  describe '#register_scope' do
    it 'registers a resource with lazy subjects and yields its keys' do
      configuration.register_scope(:reviews, group: :catalog, resources: -> { [Spree::Product] })

      expect(configuration.catalog_keys).to include('read_reviews', 'write_reviews')
      expect(configuration.scope(:reviews).resources).to eq([Spree::Product])
      expect(configuration.scope(:reviews).group).to eq(:catalog)
    end

    it 'replaces an existing registration with the same name' do
      configuration.register_scope(:reviews, group: :catalog, resources: [Spree::Product])
      configuration.register_scope(:reviews, group: :marketing, resources: [Spree::Order])

      expect(configuration.scope(:reviews).group).to eq(:marketing)
    end

    it 'reserves all — its keys would collide with the wildcard aliases' do
      expect {
        configuration.register_scope(:all, group: :catalog, resources: [Spree::Product])
      }.to raise_error(ArgumentError, /reserved/)
    end
  end

  describe 'audiences' do
    it 'grants a resource to the store back office by default' do
      configuration.register_scope(:reviews, group: :catalog, resources: [Spree::Product])

      expect(configuration.scope(:reviews)).to be_grantable_to(:store)
      expect(configuration.grantable_keys(:store)).to include('read_reviews', 'write_reviews')
    end

    # A key that only means something on the seller's own panel: granting it
    # to a store role would build a role the seller branch never consults.
    # The audience list is the whole list, so leaving the store out is how a
    # resource stays off the staff picker.
    it 'withholds a resource whose audiences leave the store out' do
      configuration.register_scope(:reviews, group: :catalog, audiences: %i[seller], resources: [Spree::Product])

      expect(configuration.scope(:reviews)).not_to be_grantable_to(:store)
      expect(configuration.scope(:seller_profile)).not_to be_grantable_to(:store)
      expect(configuration.grantable_keys(:store)).not_to include(
        'read_seller_profile', 'write_seller_profile', 'read_seller_earnings'
      )
      expect(configuration.entries.map(&:key)).not_to include('read_seller_profile')
    end

    it 'grants a resource to exactly the audiences it names' do
      configuration.register_scope(:reviews, group: :catalog, audiences: %i[store seller], resources: [Spree::Product])
      expect(configuration.scope(:reviews).audiences).to contain_exactly(:store, :seller)

      configuration.register_scope(:reviews, group: :catalog, audiences: %i[seller], resources: [Spree::Product])
      expect(configuration.scope(:reviews).audiences).to contain_exactly(:seller)
    end

    it 'withholds unnamed audiences' do
      configuration.register_scope(:reviews, group: :catalog, resources: [Spree::Product])

      expect(configuration.scope(:reviews)).not_to be_grantable_to(:seller)
      expect(configuration.grantable_keys(:seller)).not_to include('read_reviews')
    end

    it 'opens the seller-facing core resources to sellers' do
      expect(configuration.grantable_keys(:seller)).to include(
        'read_products', 'write_products', 'read_orders', 'write_orders',
        'read_fulfillments', 'write_fulfillments', 'read_stock', 'write_stock', 'read_dashboard',
        'read_package_types', 'write_package_types'
      )
    end

    # Packaging left `settings` precisely so a seller could hold it: a seller
    # owns their own boxes, and `settings` is never seller-grantable
    # (docs/plans/6.0-seller-package-types.md).
    it 'keeps package types out of the settings resource' do
      expect(configuration.scope(:settings).resources).not_to include(Spree::PackageType)
      expect(configuration.scope(:package_types).resources).to include(Spree::PackageType)
    end

    it 'never opens the operator-only resources to sellers' do
      expect(configuration.grantable_keys(:seller)).not_to include(
        'read_settings', 'write_settings', 'read_staff', 'write_staff',
        'read_api_keys', 'write_api_keys', 'read_payments', 'read_refunds'
      )
    end

    it 'reads an unregistered audience as granting nothing' do
      expect(configuration.grantable_keys(:company)).to be_empty
    end
  end

  describe '#unregister_scope' do
    it 'removes the resource and its keys' do
      configuration.register_scope(:reviews, group: :catalog, resources: [Spree::Product])
      configuration.unregister_scope(:reviews)

      expect(configuration.scope(:reviews)).to be_nil
      expect(configuration.catalog_keys).not_to include('read_reviews')
    end
  end

  describe '#resolve_key' do
    it 'resolves read and write keys' do
      kind, scope = configuration.resolve_key('write_orders')
      expect(kind).to eq(:write)
      expect(scope.name).to eq(:orders)

      kind, scope = configuration.resolve_key('read_gift_cards')
      expect(kind).to eq(:read)
      expect(scope.name).to eq(:gift_cards)
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

    # The aliases belong to secret API keys, which a store issues — so they
    # expand over what staff may hold, never over another audience's keys.
    it 'expands write_all to everything staff may hold' do
      expect(configuration.expand_keys(%w[write_all])).to eq(configuration.grantable_keys(:store))
      expect(configuration.expand_keys(%w[write_all])).not_to include('read_seller_profile')
    end

    it 'expands read_all to every read key' do
      expanded = configuration.expand_keys(%w[read_all])

      expect(expanded).to include('read_orders', 'read_products', 'read_dashboard')
      expect(expanded).not_to include('read_seller_earnings')
      expect(expanded.grep(/\Awrite_/)).to be_empty
    end

    it 'preserves catalog order' do
      expect(configuration.expand_keys(%w[write_products read_orders])).to eq(
        %w[read_orders read_products write_products]
      )
    end
  end

  describe '#scope_for_resource' do
    it 'resolves a model class to its owning resource' do
      expect(configuration.scope_for_resource(Spree::Order).name).to eq(:orders)
      expect(configuration.scope_for_resource(Spree::OptionType).name).to eq(:products)
    end

    it 'matches by ancestry so subclasses resolve to the base subject' do
      expect(configuration.scope_for_resource(Spree::Gateway).name).to eq(:settings)
    end

    it 'returns nil for classes no resource covers' do
      expect(configuration.scope_for_resource(Spree::Country)).to be_nil
      expect(configuration.scope_for_resource('not a class')).to be_nil
    end
  end

  describe '#reset!' do
    it 'restores the default catalog' do
      configuration.register_scope(:reviews, group: :catalog, resources: [Spree::Product])
      configuration.reset!

      expect(configuration.scope(:reviews)).to be_nil
      expect(configuration.scope(:orders)).to be_present
    end
  end

  describe '#assign' do
    it 'raises with upgrade directions — permission sets were removed in 6.0' do
      expect { configuration.assign(:admin, []) }.to raise_error(
        Spree::PermissionConfiguration::PermissionSetsRemovedError, /removed in Spree 6\.0/
      )
    end
  end

  describe 'seller_earnings' do
    let(:store) { @default_store }
    let(:seller) { create(:seller, store: store) }
    let(:user) { create(:admin_user) }

    def ability_with(*permissions)
      role = create(:role, name: 'seller', resource: seller, permissions: permissions)
      create(:role_user, role: role, user: user)

      Spree::Ability.new(user, resource: seller)
    end

    it 'is read-only and grantable to a seller' do
      expect(Spree.permissions.grantable_keys(:seller)).to include('read_seller_earnings')
      expect(Spree.permissions.grantable_keys(:seller)).not_to include('write_seller_earnings')
    end

    it 'grants a real ability rule' do
      expect(ability_with('read_seller_earnings')).to be_can(:read, :seller_earnings)
    end

    # The ledger classes stay the operator's: holding the seller key must not
    # open `Spree::SellerTransfer` generally.
    it 'does not let a seller manage the ledger classes' do
      expect(ability_with('read_seller_earnings')).not_to be_can(:read, Spree::SellerTransfer)
    end

    it 'is not implied by the profile key' do
      expect(ability_with('write_seller_profile')).not_to be_can(:read, :seller_earnings)
    end
  end

  describe 'seller_profile' do
    let(:store) { @default_store }
    let(:seller) { create(:seller, store: store) }
    let(:user) { create(:admin_user) }

    let(:seller_ability) do
      role = create(:role, name: 'seller', resource: seller, permissions: %w[write_seller_profile])
      create(:role_user, role: role, user: user)

      Spree::Ability.new(user, resource: seller)
    end

    # A key that grants no subject silently authorizes nothing: `authorize!` on
    # the seller branch would fail closed with the permission apparently held.
    it 'grants a real ability rule' do
      expect(seller_ability).to be_can(:manage, :seller_profile)
    end

    # The subject is a symbol so it cannot be confused with the operator's
    # `sellers` key, which owns the Spree::Seller class.
    it 'does not let a seller manage seller records' do
      expect(seller_ability).not_to be_can(:manage, seller)
    end

    it 'leaves Spree::Seller mapped to the operator resource' do
      expect(Spree.permissions.scope_for_resource(Spree::Seller).name).to eq(:sellers)
    end
  end

  # Product types are the worked example of a resource the operator writes and
  # another audience only reads. The write key has to exist — the operator's
  # endpoint serves create/update/destroy and its gate looks the key up — while
  # staying out of what a seller may be granted.
  describe 'a resource that is read-only for one audience' do
    it 'gives staff both keys' do
      expect(Spree.permissions.grantable_keys(:store)).to include('read_product_types', 'write_product_types')
    end

    it 'gives the seller audience the read alone' do
      keys = Spree.permissions.grantable_keys(:seller)

      expect(keys).to include('read_product_types')
      expect(keys).not_to include('write_product_types')
    end
  end
end
