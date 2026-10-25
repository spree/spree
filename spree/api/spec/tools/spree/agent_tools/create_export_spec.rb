require 'spec_helper'

RSpec.describe Spree::AgentTools::CreateExport do
  subject(:tool) { described_class.new(context) }

  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) { Spree::AgentTools::Context.new(store: store, user: admin, ability: ability,
                                   request_headers: agent_headers_for(admin)) }
  let(:ability) do
    Class.new do
      include CanCan::Ability
      def initialize = can(:manage, :all)
      def permission_keys = Spree.permissions.catalog_keys
    end.new
  end

  it 'is held for approval — the file leaves the building' do
    expect(described_class.mutating?).to be(true)
  end

  it 'creates an export owned by the asking admin' do
    result = tool.call(resource: 'products')

    expect(result[:ok]).to be(true)
    export = Spree::Export.find_by_prefix_id(result[:id])
    # The export builds its ability from this user, so the file contains what
    # that admin could see and nothing more.
    expect(export.user).to eq(admin)
    expect(export.store).to eq(store)
  end

  it 'carries the filters through to the export' do
    result = tool.call(resource: 'products', filters: { 'status_eq' => 'active' })

    export = Spree::Export.find_by_prefix_id(result[:id])
    # Stored as a JSON string, which is how the Admin API persists it too.
    expect(export.search_params.to_s).to include('status_eq', 'active')
  end

  it 'refuses a resource Spree cannot export, and says what it can' do
    result = tool.call(resource: 'invoices')

    expect(result[:error]).to include('invoices')
    expect(result[:available]).to include('products', 'orders')
  end

  context 'when the admin may not read the resource' do
    let(:ability) do
      Class.new do
        include CanCan::Ability
        def initialize = can(:manage, :all)
        def permission_keys = %w[read_products]
      end.new
    end

    it 'refuses to export it' do
      # Exporting is a read of every matching record, so it needs the same
      # permission reading them would.
      result = tool.call(resource: 'orders')

      expect(result[:error]).to include('permission')
      expect(Spree::Export.count).to be_zero
    end
  end
  # The code IS the instrument: whoever reads it can spend the balance, which
  # is why gift cards are kept out of the resource map and out of any order
  # payload. An export must not be the way around that — a merchant holding
  # read_gift_cards would otherwise hand a model every live code in the store.
  describe 'an export whose rows carry a bearer instrument' do
    it 'refuses to create one even for a caller who holds the scope' do
      result = tool.call(resource: 'gift_cards')

      expect(result[:error]).to include('spend money')
      expect(Spree::Export.where(store: store).count).to eq(0)
    end

    it 'refuses coupon codes too' do
      expect(tool.call(resource: 'coupon_codes')[:error]).to include('spend money')
    end
  end

end
