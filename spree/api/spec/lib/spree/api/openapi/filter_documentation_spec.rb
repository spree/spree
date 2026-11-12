require 'spec_helper'
require 'spree/api/openapi/filter_documentation'

RSpec.describe Spree::Api::OpenAPI::FilterDocumentation do
  subject(:docs) { described_class.new(endpoint, querying_path: '/querying', search: search) }

  let(:endpoint) { Spree::Api::V3::FilterTable.for(Spree::Api::V3::Admin::OrdersController) }
  let(:search) { 'Matches order number.' }

  after { Spree::Api::V3::FilterTable.reset! }

  describe '#parameters' do
    it 'lists search first, then the other scopes with their types' do
      parameters = docs.parameters

      expect(parameters.first).to include(name: 'q[search]', description: 'Matches order number.', schema: { type: :string })
      expect(parameters).to include(a_hash_including(name: 'q[complete]', schema: { type: :boolean }))
    end

    it 'describes a declared search from the attributes it matches' do
      suppliers = Spree::Api::V3::FilterTable.for(Spree::Api::V3::Admin::SuppliersController)
      parameter = described_class.new(suppliers, querying_path: '/querying').parameters.first

      expect(parameter[:description]).to eq('Matches any of name, contact name, and email (partial, case-insensitive).')
    end

    context 'when nothing says what a hand-written search matches' do
      let(:search) { nil }

      it 'refuses to document it' do
        expect { docs.parameters }.to raise_error(described_class::MissingSearchDescription, /Spree::Order/)
      end
    end
  end

  describe '#content' do
    it 'tables the attributes with their kinds and predicates' do
      expect(docs.content).to include('| `number` | Text | `eq` `not_eq`')
      expect(docs.content).to include('| `status` | One of `draft`, `placed`, `canceled` |')
      expect(docs.content).to include('`line_items_variant_`')
    end

    it 'leaves out deprecated aliases and associations back to the same records' do
      expect(docs.content).not_to include('`payment_state`')
      expect(docs.content).not_to include('`line_items_order_`')
    end
  end
end
