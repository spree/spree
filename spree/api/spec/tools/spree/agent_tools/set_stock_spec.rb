require 'spec_helper'

# "Forty in stock" is the thing a merchant says that an agent could not do at
# all before: setting a count needs an endpoint, and reaching the workflow
# directly skipped the store scoping its one caller performed.
RSpec.describe 'agent stock setting' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) do
    Spree::AgentTools::Context.new(store: store, api_key: api_key,
                                   request_headers: agent_headers_for_key(api_key))
  end
  let(:variant) { create(:product, store: store).variants.first }
  let(:location) { store.stock_locations.first || create(:stock_location, store: store) }
  let(:level) do
    Spree::StockLevel.find_or_create_by!(variant: variant, stock_location: location) do |record|
      record.count_on_hand = 5
    end
  end

  def tool(ctx = context)
    Spree.agent_tools.available_for(ctx).find { |candidate| candidate.tool_name == 'set_stock' }
  end

  def row(**attributes)
    { 'variant_id' => variant.prefixed_id, 'stock_location_id' => location.prefixed_id }.merge(
      attributes.transform_keys(&:to_s)
    )
  end

  describe 'counting a shelf' do
    it 'sets it to the figure given' do
      level

      result = tool.call(rows: [row(count_on_hand: 40, reason: 'received')])

      expect(result[:error]).to be_nil
      expect(level.reload.count_on_hand).to eq(40)
    end

    it 'adjusts it by a difference' do
      level.update!(count_on_hand: 10)

      tool.call(rows: [row(adjustment: -2, reason: 'damaged')])

      expect(level.reload.count_on_hand).to eq(8)
    end

    # Stock changes are movements so a merchant can see why a figure changed.
    it 'records the change in the stock history' do
      level

      expect { tool.call(rows: [row(count_on_hand: 40, reason: 'received')]) }.
        to change { level.reload.stock_movements.count }.by(1)
    end
  end

  describe 'refusals' do
    it 'needs at least one row' do
      expect(tool.call(rows: [])[:error]).to include('at least one row')
    end

    it 'needs a variant and a location on every row' do
      expect(tool.call(rows: [{ 'count_on_hand' => 5 }])[:error]).to include('variant_id')
    end

    # The endpoint's own refusal: a count and an adjustment together is
    # ambiguous, and it says so rather than picking one.
    it 'passes on the endpoint refusal for a contradictory row' do
      level

      result = tool.call(rows: [row(count_on_hand: 10, adjustment: 5)])

      expect(result[:error]).to be_present
      expect(result[:ok]).to be_nil
    end

    it 'is withheld from a caller who cannot write stock' do
      read_only = create(:api_key, :secret, store: store, scopes: ['read_stock'])
      read_context = Spree::AgentTools::Context.new(store: store, api_key: read_only,
                                                    request_headers: agent_headers_for_key(read_only))

      expect(tool(read_context)).to be_nil
    end

    # Another store's shelf is resolved through this store's scope, so the row
    # names nothing and nothing changes.
    it 'leaves another store\'s shelf alone' do
      theirs = create(:product, store: create(:store, code: "other-#{SecureRandom.hex(4)}")).variants.first
      their_location = create(:stock_location, store: theirs.product.store)
      their_level = Spree::StockLevel.find_or_create_by!(variant: theirs, stock_location: their_location) do |record|
        record.count_on_hand = 7
      end

      tool.call(rows: [{ 'variant_id' => theirs.prefixed_id,
                         'stock_location_id' => their_location.prefixed_id,
                         'count_on_hand' => 999 }])

      expect(their_level.reload.count_on_hand).to eq(7)
    end
  end
end
