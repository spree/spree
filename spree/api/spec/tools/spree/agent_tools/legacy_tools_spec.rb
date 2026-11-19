require 'spec_helper'

# The tools Spree 6.0.0 offered keep answering through 6.0.x, by their 6.0.0
# names and with their 6.0.0 arguments. These examples check the whole table
# rather than a sample of it, and run every name that is no longer listed end
# to end. See docs/plans/6.0-agent-tools-from-openapi.md.
RSpec.describe Spree::AgentTools::LegacyTools do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key, request_headers: agent_headers_for_key(api_key)) }
  let(:catalog) { Spree::AgentTools::OperationCatalog }

  def old_tool(name)
    Spree.admin_agent_tools.find_for(name, context)
  end

  # The 6.0.0 catalog, name => permission, read from the allowlist it was
  # built from. The constant is deprecated; reading it here is the point.
  def permissions_in_6_0_0
    Spree::AgentTools::DefaultCatalog.const_get(:WORKFLOWS).to_h do |key, options|
      permission = options.is_a?(Hash) ? options[:permission] : options
      [Spree.public_send(key).workflow_key.tr('.', '_'), permission]
    end
  end

  describe 'the table' do
    it 'resolves every 6.0.0 name to an operation' do
      unresolved = described_class::TOOLS.keys.reject { |name| catalog.find(name) }

      expect(unresolved).to be_empty
    end

    it 'maps every renamed parameter onto an argument the operation takes' do
      faults = described_class::TOOLS.flat_map do |name, tool|
        entry = catalog.find(name)
        accepted = entry.path_params + entry.body_properties.keys

        tool[:parameters].values.grep(String).reject { |target| accepted.include?(target) }.map { |target| "#{name}: #{target}" }
      end

      expect(faults).to be_empty
    end

    it 'keeps the permission each tool had in 6.0.0' do
      changed = permissions_in_6_0_0.filter_map do |name, permission|
        entry = catalog.find(name)
        next if entry.nil? # deliveries_update_tracking, withdrawn on purpose

        "#{name}: #{permission} -> #{entry.permission}" unless entry.permission == permission
      end

      expect(changed).to be_empty
    end

    it 'accounts for every 6.0.0 tool, withdrawn ones by name' do
      missing = permissions_in_6_0_0.keys - described_class::TOOLS.keys

      expect(missing).to eq(['deliveries_update_tracking'])
    end

    it 'leaves only names with no operation of their own unlisted' do
      expect(catalog.aliases.map(&:name)).to contain_exactly(
        'fulfillments_create', 'refunds_create', 'seller_requirement_submissions_waive',
        'variants_create', 'variants_update'
      )
    end
  end

  # Each name no longer listed, called the way a 6.0.0 client called it.
  describe 'a name no longer listed' do
    it 'creates a fulfillment from fulfillments_create' do
      order = create(:order_ready_to_ship, store: store)
      location = order.fulfillments.first.stock_location

      result = old_tool('fulfillments_create').call(order: order.prefixed_id, stock_location: location.prefixed_id,
                                                    tracking: 'INPOST-12345', status: 'shipped')

      expect(result[:error]).to be_nil
      expect(order.reload.fulfillments.map(&:tracking)).to include('INPOST-12345')
      expect(result[:deprecations]).to include('order is deprecated: use order_id.')
    end

    it 'refunds a payment from refunds_create' do
      order = create(:order_ready_to_ship, store: store)
      reason = create(:refund_reason)

      result = old_tool('refunds_create').call(order: order.prefixed_id, payment: order.payments.first.prefixed_id,
                                               amount: '5.00', reason: reason.prefixed_id)

      expect(result[:error]).to be_nil
      expect(Spree::Refund.where(refund_reason_id: reason.id, amount: 5)).to exist
    end

    it 'waives a requirement from seller_requirement_submissions_waive' do
      seller = create(:seller, store: store)
      requirement = create(:attestation_requirement, store: store)

      result = old_tool('seller_requirement_submissions_waive').call(seller: seller.prefixed_id,
                                                                     requirement: requirement.prefixed_id)

      expect(result[:error]).to be_nil
      expect(Spree::SellerRequirementSubmission.find_by(seller: seller, requirement: requirement)).to be_waived
    end

    it 'creates a variant from variants_create' do
      product = create(:product, store: store)
      sku = "SKU-#{SecureRandom.hex(3)}"

      result = old_tool('variants_create').call(product: product.prefixed_id, attributes: { 'sku' => sku })

      expect(result[:error]).to be_nil
      expect(product.variants.where(sku: sku)).to exist
    end

    # Named by the variant alone, as 6.0.0 took it: the product it lives
    # under is read off the variant.
    it 'updates a variant from variants_update' do
      variant = create(:variant, product: create(:product, store: store))
      sku = "SKU-#{SecureRandom.hex(3)}"

      result = old_tool('variants_update').call(variant: variant.prefixed_id, attributes: { 'sku' => sku })

      expect(result[:error]).to be_nil
      expect(variant.reload.sku).to eq(sku)
    end
  end
end
