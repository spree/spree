require 'spec_helper'

RSpec.describe Spree::Assistant::Tools::SearchResources do
  subject(:tool) { described_class.new(context) }

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


  let!(:products) { create_list(:product, 3, store: store, status: 'active') }

  describe 'counts' do
    it 'reports how many matched, not how many were returned' do
      result = tool.call(resource: 'products', limit: 2)

      # The assistant is asked to state this number; the page size would have
      # it answer "2 products" for a store holding three.
      expect(result[:total]).to eq(3)
      expect(result[:count]).to eq(2)
      expect(result[:records].size).to eq(2)
    end
  end

  describe 'records' do
    it 'carries a title and a dashboard path for each row' do
      record = tool.call(resource: 'products', limit: 1)[:records].first

      expect(record[:id]).to start_with('prod_')
      expect(record[:title]).to be_present
      expect(record[:path]).to match(%r{\A/products/prod_})
    end
  end

  describe 'filters' do
    it 'accepts a named scope' do
      result = tool.call(resource: 'products', filters: { 'in_stock' => true })

      expect(result[:error]).to be_nil
      expect(result[:total]).to eq(store.products.in_stock.count)
    end

    it 'refuses an invented filter instead of silently ignoring it' do
      # Ransack drops unknown conditions, so without this the search widens to
      # everything and the result reads as a match.
      result = tool.call(resource: 'products', filters: { 'imaginary_field_eq' => 'x' })

      expect(result[:error]).to include('imaginary_field_eq')
      expect(result[:filterable_fields]).to include('name')
      expect(result[:records]).to be_nil
    end
  end

  describe 'store scoping' do
    # An explicit code: the factory's default collides with the suite-wide
    # default store.
    let(:other_store) { create(:store, code: "other-#{SecureRandom.hex(4)}") }

    it 'never reaches another store\'s records' do
      create(:product, store: other_store, name: 'Not Yours')

      titles = tool.call(resource: 'products', limit: 25)[:records].map { |r| r[:title] }

      expect(titles).not_to include('Not Yours')
    end
  end

  describe 'permissions' do
    # Can read products but holds no order permission — the tool must refuse
    # the resource before it ever builds a query.
    let(:ability) do
      Class.new do
        include CanCan::Ability
        def initialize = can(:manage, :all)
        def permission_keys = %w[read_products]
      end.new
    end

    it 'refuses a resource the admin may not read' do
      result = tool.call(resource: 'orders')

      expect(result[:error]).to include('permission')
    end
  end
end

RSpec.describe Spree::Assistant::Tools::SearchResources, 'filter validation' do
  subject(:tool) { described_class.new(context) }

  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) { Spree::Assistant::Context.new(store: store, user: admin, ability: ability) }
  let(:ability) do
    Class.new do
      include CanCan::Ability
      def initialize = can(:manage, :all)
      def permission_keys = Spree.permissions.catalog_keys
    end.new
  end

  let!(:products) { create_list(:product, 3, store: store, status: 'active') }

  # Ransack runs with `ignore_unknown_conditions` on, so a key it cannot parse
  # is dropped and the search returns everything — which the assistant then
  # reports as the answer. Checking only the attribute half let this through.
  it 'refuses a real attribute with an invented predicate' do
    result = tool.call(resource: 'products', filters: { 'status_notarealpredicate' => 'x' })

    expect(result[:error]).to include('status_notarealpredicate')
    expect(result[:total]).to be_nil
  end

  it 'still accepts every real predicate' do
    %w[name_cont status_eq created_at_gteq].each do |key|
      result = tool.call(resource: 'products', filters: { key => 'active' })

      expect(result[:error]).to be_nil, "#{key} was rejected: #{result[:error]}"
    end
  end

  it 'accepts a bare attribute, which Ransack reads as eq' do
    expect(tool.call(resource: 'products', filters: { 'status' => 'active' })[:error]).to be_nil
  end

  it 'keeps `false` as a filter value rather than discarding it' do
    # `compact_blank` threw this away, so the search silently returned
    # everything instead of filtering.
    result = tool.call(resource: 'products', filters: { 'out_of_stock' => false })

    expect(result[:error]).to be_nil
    expect(result[:total]).to eq(store.products.out_of_stock(false).count)
  end
end
