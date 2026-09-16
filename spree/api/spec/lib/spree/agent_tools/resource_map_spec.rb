require 'spec_helper'

RSpec.describe Spree::AgentTools::ResourceMap do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) do
    Spree::AgentTools::Context.new(store: store, user: admin, ability: full_ability)
  end
  let(:full_ability) do
    Class.new do
      include CanCan::Ability
      def initialize = can(:manage, :all)
      def permission_keys = Spree.permissions.catalog_keys
    end.new
  end

  # Every entry is a promise the assistant makes to the model: this resource
  # exists, is searchable, and links somewhere real. A typo in any of the four
  # fields is invisible until a merchant asks the question that needs it.
  describe 'every registered resource' do
    Spree::AgentTools::ResourceMap.all.each do |entry|
      context "`#{entry.key}`" do
        it 'names a model that exists' do
          expect(entry.model_name.safe_constantize).to be_present
        end

        it 'names an admin serializer that exists' do
          expect(entry.serializer_name.safe_constantize).to be_present
        end

        it 'declares a permission key in the catalog' do
          expect(Spree.permissions.key?(entry.permission)).to be(true),
                                                              "#{entry.key} declares unknown permission #{entry.permission.inspect}"
        end

        it 'builds a working store-scoped relation' do
          expect { entry.scope_for(context).count }.not_to raise_error
        end

        it 'exposes filterable fields' do
          expect(entry.filterable_fields).to be_present
        end
      end
    end
  end

  # The map is derived from the controllers, one entry per model, so a
  # resource that used to be a hand-written slice of another (draft orders
  # among orders) is now reached by filtering the model's own entry. The
  # `scope_name` mechanism stays for a registration that needs it.
  describe 'a resource narrowed by a scope' do
    it 'narrows through its scope when one is registered' do
      described_class.register(key: 'draft_orders', model_name: 'Spree::Order', scope_name: :drafts,
                               permission: 'read_orders',
                               serializer_name: 'Spree::Api::V3::Admin::OrderSerializer')

      drafts = described_class.find('draft_orders')
      orders = described_class.find('orders')

      expect(drafts.model_name).to eq(orders.model_name)
      expect(drafts.scope_for(context).to_sql).not_to eq(orders.scope_for(context).to_sql)
    ensure
      Spree::Api::AgentResourceMap.install
    end
  end

  describe 'store scoping' do
    it 'reaches customers, which have no Store association' do
      # Customers are global; `for_store` is how the Admin API scopes them, and
      # the reason this map uses it rather than a Store association.
      expect { described_class.find('customers').scope_for(context).count }.not_to raise_error
    end
  end
end

RSpec.describe Spree::AgentTools::ResourceMap, 'permission alignment' do
  # A resource must not be reachable through the assistant on a looser key than
  # the Admin API demands for the same records — otherwise an admin can ask the
  # assistant for something the dashboard would refuse them, and the permission
  # layer (the one an operator reads and reasons about) is silently wrong.
  #
  # Derived from the map rather than a hand-kept list: a list only covers the
  # resources someone remembered to add, so a permission renamed in core drifts
  # silently on every resource outside it — which is exactly how
  # `delivery_methods` came to sit on `read_settings` while its controller
  # demanded `read_delivery_methods`.
  #
  # Resources whose controller resolves its permission per record (imports and
  # exports, keyed by import type) have nothing static to compare against, and
  # ones the Admin API serves from a differently-named controller are named
  # here with the controller that actually answers for them.
  DYNAMIC_PERMISSION = %w[imports exports].freeze
  CONTROLLER_OVERRIDES = { 'draft_orders' => 'OrdersController' }.freeze

  # Permissions no longer need comparing entry by entry: each one IS the
  # invoking controller's `scoped_resource`, read straight off the class. What
  # is worth asserting is that the derivation reached the controllers at all,
  # and that nothing arrived with a permission outside the catalog.
  it 'derives every entry from a controller that declares the same scope' do
    # What each controller actually declares, read the way the derivation
    # reads it, so this compares the map against its own source rather than
    # against a second list.
    declared = Spree::Api::AgentResourceMap.controllers.filter_map do |controller|
      scope = controller._scoped_resource
      model = Spree::Api::AgentResourceMap.send(:safely, controller.allocate, :model_class)
      next if scope.blank? || model.nil?

      [model.name, "read_#{scope}"]
    end

    mismatched = described_class.all.
                 # Imports and exports resolve their scope per request, so they
                 # are registered explicitly rather than derived.
                 reject { |entry| Spree::Api::AgentResourceMap::DYNAMIC_SCOPE_RESOURCES.key?(entry.key) }.
                 reject { |entry| declared.include?([entry.model_name, entry.permission]) }

    expect(mismatched.map(&:key)).to be_empty
  end

  it 'points every resource at a permission the catalog actually defines' do
    unknown = described_class.all.reject { |entry| Spree.permissions.key?(entry.permission) }

    expect(unknown.map(&:key)).to be_empty
  end
end
