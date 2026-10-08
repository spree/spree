require 'spec_helper'

# The protocol layer, exercised the way a client exercises it: by handing the
# server a JSON-RPC string and reading what comes back. No LLM anywhere — an
# MCP client is a JSON-RPC sender, so the whole surface is testable with
# factories and strings.
RSpec.describe Spree::Mcp::Server do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: scopes) }
  let(:scopes) { ['read_all'] }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key) }
  let(:server) { described_class.for(context) }

  def call(method, **params)
    message = { jsonrpc: '2.0', id: 1, method: method }
    message[:params] = params if params.any?

    JSON.parse(server.handle_json(message.to_json))
  end

  describe 'initialize' do
    it 'answers with the store name and usage instructions' do
      result = call('initialize', protocolVersion: '2026-07-28', capabilities: {},
                                  clientInfo: { name: 'rspec', version: '1' })['result']

      expect(result.dig('serverInfo', 'name')).to eq('spree-admin')
      expect(result['instructions']).to include('describe_resource')
    end
  end

  describe 'tools/list' do
    let(:tools) { call('tools/list').dig('result', 'tools') }
    let(:names) { tools.map { |tool| tool['name'] } }

    context 'with a read-only key' do
      let(:scopes) { ['read_all'] }

      it 'offers the read tools' do
        expect(names).to include('search_resources', 'get_resource', 'describe_resource')
      end

      it 'offers no tool that changes store data' do
        expect(names).not_to include('create_resource', 'update_resource', 'delete_resource')
      end

      it 'does not name a workflow tool the key could not run' do
        expect(names).not_to include('orders_cancel', 'products_update')
      end

      it 'marks a search read-only, so a client need not prompt for it' do
        search = tools.find { |tool| tool['name'] == 'search_resources' }

        expect(search.dig('annotations', 'readOnlyHint')).to be(true)
        expect(search.dig('annotations', 'destructiveHint')).to be(false)
      end

      # An export changes nothing, but it produces a file of store data and
      # mails a link to it — that leaves the building, so it is annotated for
      # confirmation even though the key only reads.
      it 'still marks an export for confirmation' do
        export = tools.find { |tool| tool['name'] == 'create_export' }

        expect(export.dig('annotations', 'destructiveHint')).to be(true)
      end
    end

    context 'with a key scoped to one resource' do
      let(:scopes) { ['write_products'] }

      it 'offers that resource\'s workflow tools' do
        expect(names).to include('products_update', 'products_activate')
      end

      it 'offers no other resource\'s write tools' do
        expect(names).not_to include('orders_cancel', 'sellers_approve')
      end
    end

    context 'with a full-access key' do
      let(:scopes) { ['write_all'] }

      it 'offers the workflow tools as destructive, so clients gate them' do
        cancel = tools.find { |tool| tool['name'] == 'orders_cancel' }

        expect(cancel.dig('annotations', 'destructiveHint')).to be(true)
        expect(cancel.dig('annotations', 'readOnlyHint')).to be(false)
      end

      it 'derives each workflow tool\'s schema from the workflow itself' do
        cancel = tools.find { |tool| tool['name'] == 'orders_cancel' }
        properties = cancel.dig('inputSchema', 'properties')

        expect(properties).to include('order', 'refund_payments', 'note')
        expect(cancel.dig('inputSchema', 'required')).to eq(['order'])
      end

      it 'never offers the principal or the store as a parameter' do
        cancel = tools.find { |tool| tool['name'] == 'orders_cancel' }
        create = tools.find { |tool| tool['name'] == 'products_create' }

        expect(cancel.dig('inputSchema', 'properties')).not_to have_key('canceler')
        expect(create.dig('inputSchema', 'properties')).not_to have_key('store')
      end

      it 'hides a deprecated parameter the allowlist excludes' do
        cancel = tools.find { |tool| tool['name'] == 'orders_cancel' }

        expect(cancel.dig('inputSchema', 'properties')).not_to have_key('restock_items')
      end

      it 'gives every tool a name the protocol accepts' do
        expect(names).to all(match(/\A[a-zA-Z0-9_-]{1,64}\z/))
      end

      # A JSON Schema array without `items` is ambiguous, and the client
      # validates arguments against the schema before the tool runs — so a
      # list parameter that does not say what it holds is refused as invalid
      # arguments, whatever the caller sends.
      it 'says what every array parameter holds' do
        arrays = tools.flat_map do |tool|
          tool.dig('inputSchema', 'properties').filter_map do |name, property|
            "#{tool['name']}.#{name}" if property['type'] == 'array' && property['items'].blank?
          end
        end

        expect(arrays).to be_empty
      end
    end
  end

  describe 'tools/call' do
    let(:scopes) { ['write_all'] }

    # The bug this guards: metrics is a list of names, and an `items: object`
    # schema made every real call fail validation before reaching the tool.
    it 'accepts a list of names for a reporting query' do
      response = call('tools/call', name: 'query_report', arguments: { 'metrics' => %w[orders] })

      expect(response.dig('result', 'isError')).to be(false)
    end

    # Claude reads the text block, so a payload that travels only as
    # structured content reaches the model as nothing. This shipped the other
    # way round once: a search answered "Found 1 match." with the match
    # stripped out, and the model could not name what it had just found.
    it 'carries the records in the text, not only in structured content' do
      create(:product, store: store, name: 'Context Budget')

      response = call('tools/call', name: 'search_resources', arguments: { 'resource' => 'products' })
      text = response.dig('result', 'content', 0, 'text').to_s

      expect(text).to include('Context Budget')
      expect(JSON.generate(response.dig('result', 'structuredContent'))).to include('Context Budget')
    end

    # The other half of the rule. A client may render the structured half,
    # the text half, or both — the protocol does not say — so a result whose
    # whole body is the answer has to carry it in the text. Naming the keys
    # and trusting the client to look elsewhere left a model reading
    # "Returned meta, families, metrics…" where it asked for the schema.
    it 'carries the answer as text when the payload is not a record list' do
      response = call('tools/call', name: 'describe_reporting', arguments: {})
      text = response.dig('result', 'content', 0, 'text').to_s

      expect(text).to include('metrics')
      expect(JSON.parse(text)).to include('families')
    end

    # A count describes an answer rather than being one. An empty result may
    # say so in a sentence, but a result holding records has to hand them
    # over — the model cannot act on "Found 2 matches."
    it 'never reduces a page of records to a count' do
      create_list(:product, 2, store: store)

      response = call('tools/call', name: 'search_resources', arguments: { 'resource' => 'products' })
      text = response.dig('result', 'content', 0, 'text').to_s

      expect(text).not_to match(/\AFound \d+ match(es)?\.\z/)
      expect(JSON.parse(text)['records'].size).to eq(2)
    end

    it 'returns structured content from a read tool' do
      create(:product, store: store, name: 'Rotary Shaver 9000')

      response = call('tools/call', name: 'search_resources',
                                    arguments: { 'resource' => 'products', 'filters' => { 'name_cont' => 'Rotary' } })

      expect(response.dig('result', 'isError')).to be(false)
      expect(response.dig('result', 'structuredContent', 'records').first['title']).to eq('Rotary Shaver 9000')
    end

    context 'when the caller was never offered the tool' do
      let(:scopes) { ['read_products'] }

      # A protocol-level error rather than a forbidden result: the tool was
      # never named to this caller, so as far as this server is concerned it
      # does not exist — which says nothing about what else the store has.
      it 'refuses at the protocol level rather than reporting forbidden' do
        response = call('tools/call', name: 'orders_cancel', arguments: { 'order' => 'order_abc' })

        expect(response).to have_key('error')
        expect(response['result']).to be_nil
        expect(response.to_s.downcase).not_to include('forbidden')
      end
    end

    it 'returns the tool\'s own refusal as a tool error the model can read' do
      response = call('tools/call', name: 'get_resource', arguments: { 'resource' => 'products', 'id' => 'prod_missing' })

      expect(response.dig('result', 'isError')).to be(true)
      expect(response.dig('result', 'content').first['text']).to include('prod_missing')
    end

    # A refusal carries what the model needs to correct itself — the fields
    # that can be filtered, the resources that exist. Forwarding only the
    # message left the model guessing at a list the tool had already built.
    it 'carries the correction hints a refusal computed' do
      response = call('tools/call', name: 'search_resources',
                                    arguments: { 'resource' => 'products', 'filters' => { 'notreal_eq' => 'x' } })
      text = response.dig('result', 'content').first['text']

      expect(response.dig('result', 'isError')).to be(true)
      expect(text).to include('notreal_eq')
      expect(text).to include('filterable_fields')
      expect(text).to include('name')
    end

    it 'refuses an id belonging to another store' do
      other_product = create(:product, store: create(:store, code: "other-#{SecureRandom.hex(4)}"), name: 'Not Ours')

      response = call('tools/call', name: 'get_resource', arguments: { 'resource' => 'products', 'id' => other_product.prefixed_id })

      expect(response.dig('result', 'isError')).to be(true)
    end

    it 'names the parameter when the arguments do not fit the schema' do
      response = call('tools/call', name: 'get_resource', arguments: { 'resource' => 'products' })

      expect(response.to_s).to include('id')
    end
  end
end
