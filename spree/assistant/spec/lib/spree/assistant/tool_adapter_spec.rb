require 'spec_helper'

RSpec.describe Spree::Assistant::ToolAdapter do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) do
    Spree::AgentTools::Context.new(store: store, user: admin, ability: ability,
                                   request_headers: agent_headers_for(admin))
  end
  let(:ability) { full_ability_for(admin) }
  # A real ability rather than a double: the tools now call `accessible_by`,
  # which needs CanCanCan's actual machinery. `admin` here is a full admin, so
  # this grants everything — record-level narrowing is exercised by core's
  # agent tool specs.
  def full_ability_for(_user)
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
    tool = Spree.admin_agent_tools.find { |candidate| candidate.tool_name == tool_name }.new(context)
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
      expect(adapter_for('products_draft').requires_approval?).to be(true)
      expect(adapter_for('search_resources').requires_approval?).to be(false)
    end

    # The tools come from core's shared registry, and anything an extension
    # registers there reaches the assistant with no assistant code involved.
    # So the gate is asserted over every write in it, not over one example.
    it 'holds every write in the registry without running it' do
      writes = Spree.admin_agent_tools.available_for(context).select(&:mutating?)
      expect(writes.size).to be > 10

      writes.each do |tool|
        expect(tool).not_to receive(:call)
        adapter = described_class.build(tool, Spree::Assistant::Turn.new)
        tool_call = RubyLLM::ToolCall.new(id: "toolu_#{tool.tool_name}", name: tool.tool_name, arguments: {})

        expect(adapter.requires_approval?).to be(true), "#{tool.tool_name} is not held for approval"
        expect(adapter.approval_resolver.call(tool_call)).to be_nil
      end
    end

    it 'holds the change and leaves the store alone' do
      adapter = adapter_for('products_draft')

      # nil is the library's "still pending", which is what stops the loop.
      expect(resolve(adapter, id: product.prefixed_id)).to be_nil
      expect(product.reload.status).to eq('active')
      expect(turn.proposal).to be_present
      expect(turn.proposal[:arguments]).to include(id: product.prefixed_id)
    end

    # The library documents a resolver as an idempotent read and may consult it
    # more than once for the same call, so re-reading must not be mistaken for
    # a second change.
    it 'records one proposal however often the same call is resolved' do
      adapter = adapter_for('products_draft')

      3.times { resolve(adapter, id: product.prefixed_id) }

      expect(turn.proposal[:tool_call_id]).to eq('toolu_1')
    end

    # A model can ask for several changes in one response. Keeping only the
    # first is what stops a merchant approving one card believing they approved
    # both.
    it 'keeps only the first of several changes in one response' do
      adapter = adapter_for('products_draft')

      other = create(:product, store: store, status: 'active')
      resolve(adapter, call_id: 'toolu_1', id: product.prefixed_id)
      resolve(adapter, call_id: 'toolu_2', id: other.prefixed_id)

      expect(turn.proposal[:tool_call_id]).to eq('toolu_1')
      expect(turn.proposal[:arguments]).to include(id: product.prefixed_id)
      expect(product.reload.status).to eq('active')
    end
  end

  describe 'the parameter schema' do
    # The library's own builder says every array holds strings; a stock
    # update's rows are objects, and a vendor validating arguments against the
    # schema would refuse the call.
    it 'says what a list holds' do
      schema = described_class.build(Spree::AgentTools::SetStock.new(context), turn).parameters_schema

      expect(schema['properties']['rows']).to include('type' => 'array', 'items' => { 'type' => 'object' })
      expect(schema['required']).to eq(['rows'])
    end

    # Operations declare no `param`s: their arguments are the request's, read
    # from the OpenAPI document. Offering them without it left the model no
    # way to name the record, and refused every argument it sent anyway.
    it 'offers an operation its own arguments' do
      adapter = adapter_for('products_draft')

      expect(adapter.parameters_schema['properties']).to include('id')
      expect(adapter.execute(id: product.prefixed_id)[:error].to_s).not_to include('Unknown argument')
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
