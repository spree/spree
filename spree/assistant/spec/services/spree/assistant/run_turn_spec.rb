require 'spec_helper'

RSpec.describe Spree::Assistant::RunTurn do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) { Spree::Assistant::Context.new(store: store, user: admin, ability: full_ability) }
  let(:chat) { Spree::AssistantChat.create!(store: store, admin_user: admin) }
  let!(:product) { create(:product, store: store, name: 'Blue Shirt', status: 'active') }

  let(:full_ability) { full_ability_for(admin) }
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


  before do
    integration = Spree::Integrations::Anthropic.new(store: store)
    integration.preferred_api_key = 'sk-test'
    integration.save!
    # Activation verifies the key, which is one provider call.
    script_provider(provider_text('ok'))
    integration.update!(active: true)
  end

  def run(message: nil)
    described_class.new(chat: chat, context: context, message: message).call
  end

  describe 'a read' do
    it 'runs the tool, answers, and remembers the lookup' do
      script_provider(
        provider_tool_use('search_resources', { resource: 'products', limit: 5 }),
        provider_text('You have one product.')
      )

      turn = run(message: 'what products do I have?')

      expect(turn.text).to eq('You have one product.')
      expect(turn).not_to be_awaiting_approval
      # The lookup is persisted, so a later turn does not repeat it.
      expect(chat.assistant_messages.where(role: 'tool').count).to eq(1)
      expect(Spree::AssistantToolCall.joins(:message).
        where(spree_assistant_messages: { chat_id: chat.id }).count).to eq(1)
    end
  end

  describe 'the tools it offers the model' do
    it 'sends real schemas, and keeps the approval gate out of the vendor payload' do
      script_provider(provider_text('hi'))
      run(message: 'hello')

      tools = last_provider_payload[:tools]
      by_name = tools.index_by { |tool| (tool[:name] || tool['name']).to_s }
      expect(by_name.keys).to include('search_resources', 'update_product_status')

      schema = by_name['search_resources'][:input_schema].deep_stringify_keys
      expect(schema['properties'].keys).to include('resource', 'filters', 'limit')
      expect(schema['required']).to eq(['resource'])

      # The gate is ours and is enforced in this process. Nothing in the
      # payload tells the vendor a tool is privileged, so a confused or
      # compromised provider has nothing to bypass.
      expect(tools.to_s).not_to include('requires_approval')
    end
  end

  describe 'a change' do
    let(:proposal) { chat.pending_tool_call }

    before do
      script_provider(provider_tool_use('update_product_status', { id: product.slug, status: 'draft' }))
    end

    it 'halts without touching the store' do
      turn = run(message: 'set Blue Shirt to draft')

      expect(turn).to be_awaiting_approval
      expect(product.reload.status).to eq('active')
      expect(proposal.status).to eq(Spree::AssistantToolCall::PROPOSED)
      expect(proposal.arguments['status']).to eq('draft')
    end

    # The gate's whole promise, asserted at the only level that proves it: run
    # a real turn through the library's own loop and watch whether the tool is
    # reached at all. Under 1.x the tool ran and refused itself; now the
    # library never calls it, so a regression here is silent unless counted.
    it 'never reaches the tool while the change is held, and reaches it once on approval' do
      calls = 0
      allow_any_instance_of(Spree::Assistant::Tools::UpdateProductStatus)
        .to receive(:call).and_wrap_original { |original, *args, **kwargs| calls += 1; original.call(*args, **kwargs) }

      run(message: 'set Blue Shirt to draft')

      expect(calls).to eq(0)
      expect(product.reload.status).to eq('active')

      Spree::Assistant::ResolveToolCall.new(tool_call: proposal, context: context, approve: true).call

      expect(calls).to eq(1)
      expect(product.reload.status).to eq('draft')
    end

    it 'writes a placeholder result so the conversation stays valid' do
      run(message: 'set Blue Shirt to draft')

      expect(proposal.result_message.content).to eq(Spree::Assistant::AWAITING_APPROVAL_MARKER)
    end

    # A model can ask to look something up and change something in one breath.
    # The read is not what the merchant is being asked to approve, so it runs;
    # only the change waits. Getting this wrong in the other direction would
    # strand the read with no result and leave the conversation invalid.
    context 'asked for alongside a read' do
      before do
        reset_scripted_provider!
        script_provider(
          provider_tool_uses(
            ['search_resources', { resource: 'products', limit: 1 }],
            ['update_product_status', { id: product.slug, status: 'draft' }]
          )
        )
      end

      it 'runs the read and still holds the change' do
        turn = run(message: 'how many products do I have, and set Blue Shirt to draft')

        expect(turn).to be_awaiting_approval
        expect(product.reload.status).to eq('active')
        expect(turn.activity.map { |entry| entry[:name] }).to include('search_resources')
      end
    end

    context 'once approved' do
      it 'applies the change and shows the model the real outcome' do
        run(message: 'set Blue Shirt to draft')
        held = proposal

        Spree::Assistant::ResolveToolCall.new(tool_call: held, context: context, approve: true).call
        expect(product.reload.status).to eq('draft')

        script_provider(provider_text('Done — Blue Shirt is a draft.'))
        run

        # The binding assertion (docs/plans/6.0-dashboard-assistant.md): assert
        # on what the provider RECEIVED, not on the visible reply. A stale
        # replay re-sends the placeholder and the model cheerfully confirms
        # work it never saw done — invisible from the reply alone.
        expect(last_tool_results_text).not_to include(Spree::Assistant::AWAITING_APPROVAL_MARKER)
        expect(last_tool_results_text).to include('draft')
      end
    end

    context 'once rejected' do
      it 'leaves the store alone and tells the model why' do
        run(message: 'set Blue Shirt to draft')
        held = proposal

        Spree::Assistant::ResolveToolCall.new(tool_call: held, context: context, approve: false).call
        expect(product.reload.status).to eq('active')
        expect(held.reload.status).to eq(Spree::AssistantToolCall::REJECTED)

        script_provider(provider_text('Understood, I left it alone.'))
        run

        expect(last_tool_results_text).to include('declined')
        expect(last_tool_results_text).not_to include(Spree::Assistant::AWAITING_APPROVAL_MARKER)
      end
    end
  end

  describe 'when no provider is connected' do
    it 'fails with a message rather than calling out' do
      store.integrations.destroy_all

      expect { run(message: 'hello') }.to raise_error(Spree::Assistant::ProviderError)
    end
  end
end
