require 'spec_helper'

# The reporting tools run the same queries the dashboard charts run, against
# the same semantic registry, so an agent and a chart cannot disagree about
# what a number means. What matters here is that the tools reach the registry,
# stay compact, and refuse a member the caller may not reference.
RSpec.describe 'agent reporting tools' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: scopes) }
  let(:scopes) { ['read_all'] }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key) }

  def tool(name)
    Spree.agent_tools.available_for(context).find { |candidate| candidate.tool_name == name }
  end

  describe 'describe_reporting' do
    it 'hands the model the real metric and dimension names' do
      result = tool('describe_reporting').call

      names = result[:metrics].map { |metric| metric[:name].to_s }

      expect(names).to include('orders', 'net_sales')
      expect(result[:dimensions]).to be_present
    end

    # A member the key cannot reference must not be offered, or the model
    # composes a query it is then refused for.
    context 'with a key that cannot read products' do
      let(:scopes) { %w[read_reports read_orders] }

      it 'leaves out the members that key could not query' do
        offered = tool('describe_reporting').call[:metrics].map { |metric| metric[:name].to_s }
        every = Spree.reporting.metrics.keys.map(&:to_s)

        expect(offered).not_to match_array(every)
      end
    end
  end

  describe 'query_report' do
    before { create(:completed_order_with_totals, store: store) }

    it 'answers with totals' do
      result = tool('query_report').call(metrics: ['orders'])

      expect(result[:error]).to be_nil
      expect(result.dig(:totals, 'orders', :value) || result.dig(:totals, :orders, :value)).to be_present
    end

    it 'groups by a dimension when asked' do
      result = tool('query_report').call(metrics: ['orders'], dimensions: ['completed_at'])

      expect(result[:error]).to be_nil
      expect(result[:rows]).to be_an(Array)
    end

    # Rows land in the model's context verbatim, so a query that would return
    # thousands is capped rather than filling the window.
    it 'caps how many rows it will return' do
      result = tool('query_report').call(metrics: ['orders'], dimensions: ['completed_at'], limit: 10_000)

      expect(result[:error]).to be_nil
      expect(result[:row_count]).to be <= Spree::AgentTools::QueryReport::MAX_LIMIT
    end

    # The registry's own rejection carries the valid names, so the model can
    # correct itself instead of guessing again.
    it 'names the valid members when given one that does not exist' do
      result = tool('query_report').call(metrics: ['profit_margin_squared'])

      expect(result[:error]).to be_present
      expect(result[:valid]).to be_present
    end

    context 'with a key lacking the scope a member needs' do
      let(:scopes) { %w[read_reports read_orders] }

      it 'refuses rather than answering from data the key cannot see' do
        product_metric = Spree.reporting.metrics.values.find { |metric| metric.key_scope == 'read_products' }
        skip 'no product-scoped metric registered' if product_metric.nil?

        result = tool('query_report').call(metrics: [product_metric.name.to_s])

        expect(result[:error]).to be_present
      end
    end
  end

  describe 'what a key without read_reports is offered' do
    let(:scopes) { ['read_products'] }

    it 'is not offered the reporting tools' do
      names = Spree.agent_tools.available_for(context).map(&:tool_name)

      expect(names).not_to include('query_report', 'describe_reporting')
    end
  end
end
