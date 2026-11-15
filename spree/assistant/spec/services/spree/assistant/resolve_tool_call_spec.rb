require 'spec_helper'

RSpec.describe Spree::Assistant::ResolveToolCall do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) do
    Spree::AgentTools::Context.new(store: store, user: admin, ability: ability,
                                   request_headers: agent_headers_for(admin))
  end
  let(:ability) do
    Class.new do
      include CanCan::Ability

      def initialize = can(:manage, :all)
      def permission_keys = Spree.permissions.catalog_keys
    end.new
  end

  let!(:product) { create(:product, store: store, status: 'active') }
  let(:chat) { Spree::AssistantChat.create!(store: store, admin_user: admin) }
  let(:message) { chat.assistant_messages.create!(role: 'assistant', content: '') }
  let!(:tool_call) do
    call = message.tool_calls.create!(
      tool_call_id: "call_#{SecureRandom.hex(4)}",
      name: 'products_draft',
      arguments: { 'id' => product.prefixed_id },
      status: Spree::AssistantToolCall::PROPOSED
    )
    chat.assistant_messages.create!(role: 'tool', content: 'AWAITING', tool_call: call)
    call
  end

  def resolve(record, approve: true)
    described_class.new(tool_call: record, context: context, approve: approve).call
  end

  it 'applies the change once' do
    resolve(tool_call)

    expect(product.reload.status).to eq('draft')
    expect(tool_call.reload.status).to eq(Spree::AssistantToolCall::EXECUTED)
  end

  it 'refuses a second decision on the same call' do
    resolve(tool_call)

    expect { resolve(tool_call.reload) }.to raise_error(Spree::Assistant::AlreadyResolvedError)
  end

  # One approval must produce exactly one change. Without an atomic claim both
  # callers passed the `awaiting_approval?` read and both ran the tool — one
  # click, two writes. Harmless for a status flip; not for a refund.
  it 'lets only one of two concurrent approvals through' do
    outcomes = []
    threads = 2.times.map do
      Thread.new do
        fresh = Spree::AssistantToolCall.find(tool_call.id)
        begin
          described_class.new(tool_call: fresh, context: context, approve: true).call
          outcomes << :executed
        rescue Spree::Assistant::AlreadyResolvedError
          outcomes << :refused
        end
      end
    end
    threads.each(&:join)

    expect(outcomes).to contain_exactly(:executed, :refused)
  end
end
