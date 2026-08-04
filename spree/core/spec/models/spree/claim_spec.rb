require 'spec_helper'

RSpec.describe Spree::Claim do
  let(:store) { @default_store }

  it 'generates a prefixed number and starts open' do
    claim = create(:claim, store: store)

    expect(claim.number).to start_with('CLM')
    expect(claim).to be_open
  end

  it 'is reachable from its order' do
    claim = create(:claim, store: store)

    expect(claim.order.reload.claims).to include(claim)
  end

  describe 'claim types' do
    around do |example|
      original = described_class.claim_types
      example.run
      described_class.claim_types = original
    end

    it 'rejects a type outside the configured list' do
      expect(build(:claim, store: store, claim_type: 'teleported')).not_to be_valid
    end

    # Types are labels with no per-type behaviour, so extending needs no
    # accompanying workflow.
    it 'accepts a type an extension added' do
      described_class.claim_types += ['late_delivery']

      expect(create(:claim, store: store, claim_type: 'late_delivery')).to be_persisted
    end
  end

  it 'rejects a resolution outside the closed set' do
    expect(build(:claim, store: store, resolution: 'apologize')).not_to be_valid
  end

  describe Spree::ClaimLineItem do
    let(:claim) { create(:claim, store: store) }
    let(:line) { claim.claim_line_items.first }

    it 'caps a refund at what the customer paid for the units' do
      line_item = line.line_item

      expect(line.paid_amount).to eq(line_item.amount / line_item.quantity)
    end

    it 'sends the original variant when no replacement is named' do
      expect(line.variant_to_send).to eq(line.variant)
    end

    it 'sends the replacement when one is named' do
      replacement = create(:variant)
      line.update!(replacement_variant: replacement)

      expect(line.variant_to_send).to eq(replacement)
    end
  end
end
