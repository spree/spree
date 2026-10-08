require 'spec_helper'

# Merchandising is largely membership, so this is one of the writes a merchant
# asks for most. It runs over every parent the Admin API exposes its nested
# products surface for, derived rather than listed.
RSpec.describe 'agent product curation' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key) }

  def tool(ctx = context)
    Spree.agent_tools.available_for(ctx).find { |candidate| candidate.tool_name == 'curate_products' }
  end

  describe 'the derived set of parents' do
    # A parent that adopts the membership concern should be curated without
    # anyone editing a list, which is the whole reason the map is derived.
    it 'covers every parent the Admin API curates products for' do
      expect(Spree::AgentTools::MembershipMap.targets).to include('category', 'collection', 'catalog', 'price_list')
    end

    it 'gates each one on its own write permission' do
      expect(Spree::AgentTools::MembershipMap.find('category').permission).to eq('write_categories')
      expect(Spree::AgentTools::MembershipMap.find('collection').permission).to eq('write_collections')
    end
  end

  describe 'adding and removing' do
    let(:category) { create(:category, store: store) }
    let(:product) { create(:product, store: store) }

    it 'adds a product and reports what changed' do
      result = tool.call(target: 'category', id: category.prefixed_id, products: [product.prefixed_id])

      expect(result[:error]).to be_nil
      expect(result[:added]).to eq(1)
      expect(category.reload.products).to include(product)
    end

    # The count is read back from membership rather than taken from the
    # input, so a product already there is reported as such instead of
    # counted a second time.
    it 'reports a product that was already a member' do
      tool.call(target: 'category', id: category.prefixed_id, products: [product.prefixed_id])
      result = tool.call(target: 'category', id: category.prefixed_id, products: [product.prefixed_id])

      expect(result[:added]).to eq(0)
      expect(result[:already_present]).to eq(1)
    end

    it 'removes a product' do
      tool.call(target: 'category', id: category.prefixed_id, products: [product.prefixed_id])
      result = tool.call(target: 'category', id: category.prefixed_id,
                         products: [product.prefixed_id], operation: 'remove')

      expect(result[:removed]).to eq(1)
      expect(category.reload.products).not_to include(product)
    end

    it 'reports a product that was never a member' do
      result = tool.call(target: 'category', id: category.prefixed_id,
                         products: [product.prefixed_id], operation: 'remove')

      expect(result[:removed]).to eq(0)
      expect(result[:not_a_member]).to eq(1)
    end
  end

  describe 'refusals' do
    let(:category) { create(:category, store: store) }
    let(:product) { create(:product, store: store) }

    it 'names the parents it can curate when given one it cannot' do
      result = tool.call(target: 'shelf', id: category.prefixed_id, products: [product.prefixed_id])

      expect(result[:error]).to include('shelf')
      expect(result[:available_targets]).to include('category')
    end

    # The server promises that a tool a caller cannot see is one the store has
    # not granted, so a write offered to a read-only grant breaks that promise.
    it 'is not offered to a caller who can curate nothing' do
      read_only = create(:api_key, :secret, store: store, scopes: %w[read_categories read_products])
      read_context = Spree::AgentTools::Context.new(store: store, api_key: read_only)

      expect(tool(read_context)).to be_nil
    end

    # A caller correcting itself should not pick a parent it will then be
    # refused for.
    it 'names only the parents the caller may curate' do
      partial = create(:api_key, :secret, store: store, scopes: %w[write_categories read_products])
      partial_context = Spree::AgentTools::Context.new(store: store, api_key: partial)

      result = tool(partial_context).call(target: 'shelf', id: category.prefixed_id,
                                          products: [product.prefixed_id])

      expect(result[:available_targets]).to include('category')
      expect(result[:available_targets]).not_to include('collection')
    end

    it 'refuses a caller holding only the read permission' do
      elsewhere = create(:api_key, :secret, store: store, scopes: %w[write_collections read_categories read_products])
      limited = Spree::AgentTools::Context.new(store: store, api_key: elsewhere)

      result = tool(limited).call(target: 'category', id: category.prefixed_id,
                                  products: [product.prefixed_id])

      expect(result[:error]).to include('permission')
      expect(category.reload.products).to be_empty
    end

    # The parent is looked up through the store's own scope, so another
    # store's category is not found rather than quietly curated.
    it 'cannot reach a parent belonging to another store' do
      other_category = create(:category, store: create(:store))

      result = tool.call(target: 'category', id: other_category.prefixed_id,
                         products: [product.prefixed_id])

      expect(result[:error]).to include('No category found')
      expect(other_category.reload.products).to be_empty
    end

    it 'ignores a product id that names nothing in this store' do
      foreign = create(:product, store: create(:store))

      result = tool.call(target: 'category', id: category.prefixed_id, products: [foreign.prefixed_id])

      expect(result[:error]).to include('name a product in this store')
      expect(category.reload.products).to be_empty
    end
  end
end
