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
    it 'halts rather than executing' do
      result = adapter_for('update_product_status').execute(id: product.slug, status: 'draft')

      expect(result).to be_a(RubyLLM::Tool::Halt)
      expect(product.reload.status).to eq('active')
      expect(turn.proposal).to be_present
    end

    it 'refuses a second change in the same turn' do
      adapter = adapter_for('update_product_status')
      adapter.execute(id: product.slug, status: 'draft')

      second = adapter.execute(id: product.slug, status: 'archived')

      # Every call in a response runs before the halt takes effect, so without
      # this the merchant approves one change believing they approved both.
      expect(second).to be_a(Hash)
      expect(second[:error]).to include('already waiting')
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
