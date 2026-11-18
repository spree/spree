# Phase 0 spike for docs/plans/6.0-dashboard-assistant.md
#
# Proves, against ruby_llm 1.16.0 with a stubbed Anthropic endpoint:
#   1. a mutating tool HALTS the agent loop instead of executing
#   2. the halted call is persisted with its arguments, awaiting approval
#   3. APPROVE executes the real work and the conversation resumes
#   4. REJECT feeds a declined result back and the conversation resumes
#   5. the model only ever sees tools the current user's permissions allow
#
# Run: bundle exec ruby spike.rb

require 'bundler/setup'
require 'active_record'
require 'ruby_llm'
require 'ruby_llm/active_record/chat_methods'
require 'ruby_llm/active_record/message_methods'
require 'ruby_llm/active_record/tool_call_methods'
require 'ruby_llm/active_record/model_methods'
require 'ruby_llm/active_record/acts_as'
require 'webmock'
require 'json'

include WebMock::API
WebMock.enable!

# ---------------------------------------------------------------- schema ----

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.verbose = false

ActiveRecord::Schema.define do
  create_table :models do |t|
    t.string :model_id, :name, :provider, :family
    t.integer :context_window, :max_output_tokens
    t.json :capabilities, :modalities, :pricing, :metadata
    t.timestamps
  end

  create_table :chats do |t|
    t.references :model
    t.timestamps
  end

  create_table :messages do |t|
    t.references :chat
    t.references :model
    t.references :tool_call        # parent tool call — FK name is `tool_call_id`
    t.string :role, null: false
    t.text :content
    t.json :content_raw
    t.text :thinking_text, :thinking_signature
    t.integer :thinking_tokens, :input_tokens, :output_tokens,
              :cached_tokens, :cache_creation_tokens
    t.timestamps
  end

  create_table :tool_calls do |t|
    t.references :message
    t.string :tool_call_id, null: false
    t.string :name, null: false
    t.text :thought_signature
    t.json :arguments, default: {}
    # Spree's addition: the approval lifecycle lives on the tool-call row.
    t.string :status
    t.timestamps
  end
end

class Model < ActiveRecord::Base
  include RubyLLM::ActiveRecord::ActsAs
  acts_as_model
end

class Chat < ActiveRecord::Base
  include RubyLLM::ActiveRecord::ActsAs
  acts_as_chat
end

class Message < ActiveRecord::Base
  include RubyLLM::ActiveRecord::ActsAs
  acts_as_message
end

class ToolCall < ActiveRecord::Base
  include RubyLLM::ActiveRecord::ActsAs
  acts_as_tool_call

  PROPOSED = 'proposed'
  APPROVED = 'approved'
  REJECTED = 'rejected'
  EXECUTED = 'executed'
end

# ------------------------------------------------- Spree-shaped registry ----
#
# Stands in for Spree::Assistant.tools. Tools are plain Spree objects: the
# RubyLLM class is a generated adapter, so the registry stays reusable by a
# future MCP server and survives a client-library swap.

ToolDefinition = Struct.new(
  :name, :description, :params, :permission, :mutating, :summary, :executor,
  keyword_init: true
) do
  def mutating? = !!mutating
end

REGISTRY = [
  ToolDefinition.new(
    name: 'search_products',
    description: 'Search the catalog. Returns matching products.',
    params: { query: { type: 'string', description: 'Search term' } },
    permission: 'read_products',
    mutating: false,
    summary: ->(args) { "Search products for #{args[:query].inspect}" },
    executor: ->(_ctx, args) {
      { products: [{ id: 'prod_86Rf07xd4z', name: "Blue Shirt (#{args[:query]})", price: '29.00' }] }
    }
  ),
  ToolDefinition.new(
    name: 'update_product_price',
    description: 'Change a product price.',
    params: {
      product_id: { type: 'string', description: 'Prefixed product id' },
      price: { type: 'string', description: 'New price' }
    },
    permission: 'write_products',
    mutating: true,
    summary: ->(args) { "Set price of #{args[:product_id]} to #{args[:price]}" },
    executor: lambda { |ctx, args|
      # Real implementation calls the same workflow the Admin API uses.
      ctx[:audit] << [:price_written, args[:product_id], args[:price]]
      { ok: true, product_id: args[:product_id], price: args[:price] }
    }
  )
].freeze

# The adapter. `halt` is what makes the approval gate possible: RubyLLM stops
# the loop and hands the Halt back up through `complete`.
def build_ruby_llm_tool(definition, context)
  Class.new(RubyLLM::Tool) do
    define_singleton_method(:name) { "SpikeTool#{definition.name.split('_').map(&:capitalize).join}" }
    description definition.description

    definition.params.each { |param_name, opts| param param_name, **opts }

    define_method(:name) { definition.name }

    define_method(:execute) do |**args|
      if definition.mutating?
        context[:pending] = { name: definition.name, arguments: args }
        # Persisted as the tool-result message; overwritten on approval.
        halt("AWAITING_APPROVAL: #{definition.summary.call(args)}")
      else
        context[:audit] << [:read_executed, definition.name]
        definition.executor.call(context, args)
      end
    end
  end.new
end

def tools_for(permissions, context)
  REGISTRY.select { |definition| permissions.include?(definition.permission) }
          .map { |definition| build_ruby_llm_tool(definition, context) }
end

# ------------------------------------------------------- stubbed provider ---
#
# Deterministic scripted Anthropic responses, so the spike proves the control
# flow rather than the model's behaviour, and runs with no API key in CI.

SCRIPT = []

def anthropic_text(text)
  { id: 'msg_x', type: 'message', role: 'assistant', model: 'claude-sonnet-4-5',
    content: [{ type: 'text', text: text }],
    stop_reason: 'end_turn', usage: { input_tokens: 10, output_tokens: 5 } }
end

def anthropic_tool_use(id, name, input)
  { id: 'msg_x', type: 'message', role: 'assistant', model: 'claude-sonnet-4-5',
    content: [{ type: 'tool_use', id: id, name: name, input: input }],
    stop_reason: 'tool_use', usage: { input_tokens: 10, output_tokens: 5 } }
end

LAST_REQUEST = { body: nil }

stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return do |request|
  LAST_REQUEST[:body] = JSON.parse(request.body)
  { status: 200, headers: { 'Content-Type' => 'application/json' },
    body: (SCRIPT.shift || anthropic_text('(script exhausted)')).to_json }
end

RubyLLM.configure do |config|
  config.anthropic_api_key = 'test-key'
  config.default_model = 'claude-sonnet-4-5'
  config.log_level = :fatal
end

# ------------------------------------------------------------ turn driver ---
#
# Stands in for Spree::Assistant::RunTurn.

def run_turn(chat_record, permissions, context, message: nil)
  context[:pending] = nil
  llm_tools = tools_for(permissions, context)

  chat_record.with_tools(*llm_tools) if llm_tools.any?
  result = message ? chat_record.ask(message) : chat_record.complete

  if context[:pending]
    proposal = chat_record.messages.reload.last            # the halted tool-result row
    call = ToolCall.find_by!(name: context[:pending][:name], status: nil)
    call.update!(status: ToolCall::PROPOSED)
    { halted: true, proposal: proposal, tool_call: call, result: result }
  else
    { halted: false, result: result }
  end
end

# Approving replaces the placeholder tool result with the real one, then
# resumes. `to_llm` rebuilds the in-memory conversation from the rows, so the
# model sees the executed result exactly where it expects it.
def resolve(chat_record, tool_call, context, permissions, approve:)
  definition = REGISTRY.find { |d| d.name == tool_call.name }
  args = tool_call.arguments.transform_keys(&:to_sym)

  content =
    if approve
      tool_call.update!(status: ToolCall::APPROVED)
      payload = definition.executor.call(context, args)
      tool_call.update!(status: ToolCall::EXECUTED)
      payload.to_json
    else
      tool_call.update!(status: ToolCall::REJECTED)
      { declined: true, reason: 'The user rejected this action.' }.to_json
    end

  tool_call.result.update!(content: content)

  # Resume: drop the memoized RubyLLM chat AND the cached association, so
  # `to_llm` replays the rows as they now stand (with the real tool result).
  chat_record.instance_variable_set(:@chat, nil)
  chat_record.reload

  run_turn(chat_record, permissions, context)
end

# ------------------------------------------------------------------ tests ---

FAILURES = []

def check(label, condition, detail = nil)
  if condition
    puts "  ✅ #{label}"
  else
    puts "  ❌ #{label}#{detail ? " — #{detail}" : ''}"
    FAILURES << label
  end
end

ADMIN_PERMISSIONS = %w[read_products write_products].freeze
VIEWER_PERMISSIONS = %w[read_products].freeze

puts "\n── 1. Read tool auto-executes, no approval ─────────────────────────"
SCRIPT.replace([
  anthropic_tool_use('toolu_1', 'search_products', { 'query' => 'shirt' }),
  anthropic_text('I found one product: Blue Shirt at $29.00.')
])
context = { audit: [] }
chat = Chat.create!(model: 'claude-sonnet-4-5')
turn = run_turn(chat, ADMIN_PERMISSIONS, context, message: 'find shirts')

check('turn completed without halting', turn[:halted] == false)
check('read tool executed', context[:audit].include?([:read_executed, 'search_products']))
check('assistant answered', turn[:result].content.include?('Blue Shirt'))

puts "\n── 2. Mutating tool halts and is persisted as proposed ─────────────"
SCRIPT.replace([anthropic_tool_use('toolu_2', 'update_product_price',
                                   { 'product_id' => 'prod_86Rf07xd4z', 'price' => '19.00' })])
context = { audit: [] }
chat = Chat.create!(model: 'claude-sonnet-4-5')
turn = run_turn(chat, ADMIN_PERMISSIONS, context, message: 'drop the blue shirt to 19')

check('loop halted', turn[:halted] == true)
check('nothing was written', context[:audit].none? { |e| e.first == :price_written },
      context[:audit].inspect)
check('tool call persisted as proposed', turn[:tool_call].status == ToolCall::PROPOSED)
check('arguments persisted for the approval card',
      turn[:tool_call].arguments['price'] == '19.00', turn[:tool_call].arguments.inspect)
check('placeholder tool result persisted in the right slot',
      turn[:proposal].role == 'tool' && turn[:proposal].content.start_with?('AWAITING_APPROVAL'),
      "#{turn[:proposal].role}: #{turn[:proposal].content}")

puts "\n── 3. Approval executes and the conversation resumes ───────────────"
SCRIPT.replace([anthropic_text('Done — the Blue Shirt is now $19.00.')])
resumed = resolve(chat, turn[:tool_call], context, ADMIN_PERMISSIONS, approve: true)

check('work executed on approval',
      context[:audit].include?([:price_written, 'prod_86Rf07xd4z', '19.00']))
check('tool call marked executed', turn[:tool_call].reload.status == ToolCall::EXECUTED)
check('conversation resumed', resumed[:halted] == false)
check('model confirmed the change', resumed[:result].content.include?('$19.00'))

sent_tool_result = LAST_REQUEST[:body]['messages']
                   .flat_map { |m| m['content'].is_a?(Array) ? m['content'] : [] }
                   .find { |b| b['type'] == 'tool_result' }
sent_text = sent_tool_result && sent_tool_result['content'].to_s
check('model received the REAL result, not the placeholder',
      sent_text&.include?('ok') && sent_text.include?('19.00') &&
        !sent_text.include?('AWAITING_APPROVAL'),
      sent_tool_result.inspect)

puts "\n── 4. Rejection is reported back and the conversation resumes ──────"
SCRIPT.replace([anthropic_tool_use('toolu_3', 'update_product_price',
                                   { 'product_id' => 'prod_86Rf07xd4z', 'price' => '1.00' })])
context = { audit: [] }
chat = Chat.create!(model: 'claude-sonnet-4-5')
turn = run_turn(chat, ADMIN_PERMISSIONS, context, message: 'make it 1 dollar')

SCRIPT.replace([anthropic_text('Understood — I left the price unchanged.')])
resumed = resolve(chat, turn[:tool_call], context, ADMIN_PERMISSIONS, approve: false)

check('nothing written on rejection', context[:audit].none? { |e| e.first == :price_written })
check('tool call marked rejected', turn[:tool_call].reload.status == ToolCall::REJECTED)
check('conversation resumed after rejection', resumed[:halted] == false)

sent_tool_result = LAST_REQUEST[:body]['messages']
                   .flat_map { |m| m['content'].is_a?(Array) ? m['content'] : [] }
                   .find { |b| b['type'] == 'tool_result' }
sent_text = sent_tool_result && sent_tool_result['content'].to_s
check('model was told the user declined',
      sent_text&.include?('declined') && !sent_text.include?('AWAITING_APPROVAL'),
      sent_tool_result.inspect)

puts "\n── 5. Tools are filtered by the signed-in user's permissions ───────"
SCRIPT.replace([anthropic_text('I can only look things up.')])
context = { audit: [] }
chat = Chat.create!(model: 'claude-sonnet-4-5')
run_turn(chat, VIEWER_PERMISSIONS, context, message: 'drop the price')

offered = (LAST_REQUEST[:body]['tools'] || []).map { |t| t['name'] }
check('read tool offered', offered.include?('search_products'), offered.inspect)
check('mutating tool hidden from a user without write_products',
      !offered.include?('update_product_price'), offered.inspect)

puts "\n" + '─' * 68
if FAILURES.empty?
  puts "GO — all #{`grep -c 'check(' #{__FILE__}`.to_i} checks passed. RubyLLM supports the approval gate."
else
  puts "NO-GO — #{FAILURES.size} failed: #{FAILURES.join(', ')}"
end
exit(FAILURES.empty? ? 0 : 1)
