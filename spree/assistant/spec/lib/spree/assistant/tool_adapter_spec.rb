require 'spec_helper'

RSpec.describe Spree::Assistant::ToolAdapter do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) { Spree::Assistant::Context.new(store: store, user: admin, ability: ability) }
  let(:ability) { full_ability_for(admin) }
  # A real ability rather than a double: the tools now call `accessible_by`,
  # which needs CanCanCan's actual machinery. `admin` here is a full admin, so
  # this grants everything — record-level narrowing is exercised in
  # spec/authorization_spec.rb.
  def full_ability_for(user)
    Class.new do
      include CanCan::Ability

      def initialize
        can :manage, :all
      end

      def permission_keys
        Spree.permissions.catalog_keys
      end
    end.new
  end

  let(:turn) { Spree::Assistant::Turn.new }

  let!(:product) { create(:product, store: store, status: 'active') }

  def adapter_for(tool_name)
    tool = Spree::Assistant.tools.find_by_name(tool_name).new(context)
    described_class.build(tool, turn)
  end

  describe 'argument checking' do
    # The library skips its own validation for this method shape, so a missing
    # argument would otherwise raise out of the turn and the merchant would see
    # a generic failure instead of the assistant correcting itself.
    it 'reports a missing argument as a result the model can read' do
      result = adapter_for('get_resource').execute(resource: 'products')

      expect(result[:error]).to include('Missing required')
      expect(result[:error]).to include('id')
    end

    it 'reports an unknown argument' do
      result = adapter_for('get_resource').execute(resource: 'products', id: 'x', nonsense: 1)

      expect(result[:error]).to include('Unknown argument')
    end
  end

  describe 'a mutating tool' do
    # The gate is the library's own: a tool declaring `requires_approval` whose
    # resolver answers "pending" is never executed, so the assertions here are
    # about the declaration and the resolver rather than about `execute` — the
    # adapter no longer has a way to hold a call itself.
    def resolve(adapter, call_id: 'toolu_1', **arguments)
      tool_call = RubyLLM::ToolCall.new(id: call_id, name: adapter.name, arguments: arguments.stringify_keys)
      adapter.approval_resolver.call(tool_call)
    end

    it 'is declared to the library as needing approval' do
      expect(adapter_for('update_product_status').requires_approval?).to be(true)
      expect(adapter_for('search_resources').requires_approval?).to be(false)
    end

    it 'holds the change and leaves the store alone' do
      adapter = adapter_for('update_product_status')

      # nil is the library's "still pending", which is what stops the loop.
      expect(resolve(adapter, id: product.slug, status: 'draft')).to be_nil
      expect(product.reload.status).to eq('active')
      expect(turn.proposal).to be_present
      expect(turn.proposal[:arguments]).to include(id: product.slug, status: 'draft')
    end

    # The library documents a resolver as an idempotent read and may consult it
    # more than once for the same call, so re-reading must not be mistaken for
    # a second change.
    it 'records one proposal however often the same call is resolved' do
      adapter = adapter_for('update_product_status')

      3.times { resolve(adapter, id: product.slug, status: 'draft') }

      expect(turn.proposal[:tool_call_id]).to eq('toolu_1')
      expect(turn.proposal[:arguments]).to include(status: 'draft')
    end

    # A model can ask for several changes in one response. Keeping only the
    # first is what stops a merchant approving one card believing they approved
    # both.
    it 'keeps only the first of several changes in one response' do
      adapter = adapter_for('update_product_status')

      resolve(adapter, call_id: 'toolu_1', id: product.slug, status: 'draft')
      resolve(adapter, call_id: 'toolu_2', id: product.slug, status: 'archived')

      expect(turn.proposal[:tool_call_id]).to eq('toolu_1')
      expect(turn.proposal[:arguments]).to include(status: 'draft')
      expect(product.reload.status).to eq('active')
    end
  end

  describe 'the tool budget' do
    it 'stops a model that keeps calling the same tool' do
      adapter = adapter_for('search_resources')

      results = Array.new(Spree::Assistant::Turn::MAX_TOOL_CALLS + 2) do
        turn.record_activity(name: 'search_resources', arguments: {})
        adapter.execute(resource: 'products', limit: 1)
      end

      expect(results.last[:error]).to include('limit reached')
    end
  end
end

RSpec.describe 'tool declaration inheritance' do
  # Subclassing a tool is the documented extension path. With declarations in
  # bare class-level ivars, a subclass came back `mutating? == false` — so a
  # host tweaking a write tool got one that skipped the approval card, the
  # permission gate and argument validation all at once.
  let(:subclass) { Class.new(Spree::Assistant::Tools::UpdateProductStatus) }

  it 'keeps the mutating flag, so the approval gate still applies' do
    expect(subclass.mutating?).to be(true)
  end

  it 'keeps the permission gate' do
    expect(subclass.permission).to eq('write_products')
  end

  it 'keeps the name and params' do
    expect(subclass.tool_name).to eq('update_product_status')
    expect(subclass.params.keys).to contain_exactly(:id, :status)
  end

  it 'does not leak a subclass param back onto its parent' do
    subclass.param(:extra, description: 'only here')

    expect(subclass.params).to have_key(:extra)
    expect(Spree::Assistant::Tools::UpdateProductStatus.params).not_to have_key(:extra)
  end
end
