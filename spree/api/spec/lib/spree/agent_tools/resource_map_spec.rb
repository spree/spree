require 'spec_helper'

RSpec.describe Spree::AgentTools::ResourceMap do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) do
    Spree::AgentTools::Context.new(store: store, user: admin, ability: full_ability,
                                   request_headers: agent_headers_for(admin))
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

        it 'declares permission keys in the catalog' do
          unknown = entry.permission_keys.reject { |key| Spree.permissions.key?(key) }

          expect(entry.permission_keys).to be_present
          expect(unknown).to be_empty, "#{entry.key} declares unknown permissions #{unknown.inspect}"
        end

        it 'builds a working store-scoped relation' do
          expect { entry.scope_for(context).count }.not_to raise_error
        end

        it 'exposes filterable fields' do
          expect(entry.filterable_fields).to be_present
        end

        it 'lists only filters the database can run' do
          entry.filterable_fields.each do |field|
            filter = { "#{field}_null" => false }
            expect { entry.scope_for(context).ransack(filter).result.load }.not_to raise_error, "#{entry.key} lists `#{field}`, which fails to filter"
          end
        end
      end
    end
  end

  # The map is derived from the controllers, one entry per model, so a
  # resource that used to be a hand-written slice of another (draft orders
  # among orders) is now reached by filtering the model's own entry. The
  # `scope_name` mechanism stays for a registration that needs it.
  # A delivery carries the whole event body — the customer's email, name and
  # address — and its serializer only redacts that when the caller passes a
  # permission gate. Withholding the endpoint while exposing its deliveries
  # would hand a `read_webhooks` grant the customer data that scope exists to
  # stay clear of.
  describe 'resources that carry another scope\'s data' do
    it 'withholds webhook deliveries along with their endpoint' do
      keys = described_class.all.map(&:key)

      expect(keys).not_to include('webhook_deliveries')
      expect(keys).not_to include('webhook_endpoints')
    end
  end

  # Postgres refuses SELECT DISTINCT beside an ORDER BY the select list does
  # not carry, which is why some controllers turn it off. A search adding it
  # anyway answered every price query with a 500.
  # A tool names an operation, so the map has to know where each resource's
  # operations live. Read from the routes rather than built from the key.
  describe 'the Admin API path for a resource' do
    it 'is the top-level route, not a nested one' do
      expect(described_class.find('products').api_path(:index)).to eq('/api/v3/admin/products')
      expect(described_class.find('products').api_path(:show)).to eq('/api/v3/admin/products/:id')
    end

    # Products are served by five controllers, including
    # `catalogs/products`. Collisions resolve by permission breadth, which
    # says nothing about depth — so the winner kept whichever path won on
    # scope, and a tool was handed `:catalog_id` with nothing to fill it.
    it 'prefers the shallowest path across colliding controllers' do
      %w[products orders variants].each do |key|
        expect(described_class.find(key).api_path(:index)).not_to include(':')
      end
    end

    it 'keeps the parent segment for a genuinely nested resource' do
      expect(described_class.find('line_items').api_path(:index)).to include(':')
    end

    # A `?` would end the path, sending a line item's delete to the order.
    it 'keeps a caller-supplied id inside its own segment' do
      path = described_class.find('line_items').path_for(:destroy, id: 'li_1', parent_id: 'or_1?x=y')

      expect(path).to end_with('/orders/or_1%3Fx%3Dy/items/li_1')
    end

    it 'refuses a path it cannot fill completely' do
      entry = described_class.find('line_items')
      allow(entry).to receive(:api_path).and_return('/api/v3/admin/stores/:store_id/orders/:order_id/items/:id')

      expect(entry.path_for(:show, id: 'li_1', parent_id: 'or_1')).to be_nil
    end

    it 'knows which resources a tool can dispatch to' do
      expect(described_class.find('products')).to be_dispatchable
      expect(described_class.find('imports')).to be_dispatchable
      expect(described_class.all.find { |entry| entry.nested?(:index) }).not_to be_dispatchable
    end
  end

  describe 'a resource whose controller disables DISTINCT' do
    it 'carries that through to the map' do
      expect(described_class.find('prices').distinct?).to be(false)
    end

    # One controller refusing is enough — whichever sorted first is not an
    # answer, and products is served by five.
    it 'refuses when any colliding controller refuses' do
      expect(described_class.find('products').distinct?).to be(false)
    end

    it 'leaves it on where no controller objects' do
      expect(described_class.find('orders').distinct?).to be(true)
    end
  end

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
    unknown = described_class.all.reject do |entry|
      entry.permission_keys.any? && entry.permission_keys.all? { |key| Spree.permissions.key?(key) }
    end

    expect(unknown.map(&:key)).to be_empty
  end

  # Imports and exports are gated by the scope of the type each one carries,
  # the way their controllers gate them.
  it 'opens exports to a reader of any exported resource and imports to a writer' do
    expect(described_class.find('exports').access_permissions).to include('read_products', 'read_orders', 'read_customers')
    expect(described_class.find('imports').access_permissions).to include('write_products', 'write_customers')
    expect(described_class.find('imports').access_permissions).not_to include('read_products')
  end
end
