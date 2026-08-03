require 'spec_helper'

RSpec.describe 'Spree::Claims workflows' do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store, line_items_count: 2) }
  let(:line_item) { order.line_items.first }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  def create_claim(**overrides)
    Spree::Claims::Create.call(
      order: order,
      claim_type: 'damaged',
      items: [{ line_item: line_item, quantity: 1, description: 'Cracked', refund_amount: line_item.price }],
      **overrides
    )
  end

  describe Spree::Claims::Create do
    it 'opens a claim' do
      result = create_claim

      expect(result).to be_success
      expect(result.value).to be_open
      expect(result.value.claim_type).to eq('damaged')
    end

    it 'refuses an unknown claim type' do
      expect(create_claim(claim_type: 'teleported')).to be_failure
    end

    it 'refuses claiming more than was ordered' do
      result = Spree::Claims::Create.call(
        order: order,
        items: [{ line_item: line_item, quantity: line_item.quantity + 5 }]
      )

      expect(result).to be_failure
    end

    it 'lets a validate handler gate self-service claims' do
      Spree.hooks.register('claims.create.validate') { |flow| flow.reject!('claims disabled') }

      expect(create_claim).to be_failure
    end
  end

  describe Spree::Claims::Approve do
    it 'approves an open claim' do
      claim = create_claim.value

      expect(Spree::Claims::Approve.call(claim: claim).value).to be_approved
    end
  end

  describe Spree::Claims::Resolve do
    let(:claim) { create(:approved_claim, store: store, order: order) }

    it 'refuses an unapproved claim' do
      open_claim = create_claim.value

      expect(Spree::Claims::Resolve.call(claim: open_claim, resolution: 'refund')).to be_failure
    end

    it 'refuses an unknown resolution' do
      expect(Spree::Claims::Resolve.call(claim: claim, resolution: 'apologize')).to be_failure
    end

    it 'refunds to store credit' do
      result = Spree::Claims::Resolve.call(claim: claim, resolution: 'refund')

      expect(result).to be_success
      expect(result.value).to be_resolved
      expect(result.value.resolution).to eq('refund')
      expect(Spree::StoreCredit.find_by(originator: claim)).to be_present
    end

    it 'refuses to refund more than the customer paid' do
      result = Spree::Claims::Resolve.call(claim: claim, resolution: 'refund', amount: 10_000)

      expect(result).to be_failure
      expect(result.error.value).to eq(:refund_exceeds_paid)
    end

    it 'ships a replacement' do
      claim = create(:approved_claim, store: store, order: order, send_replacement: true)
      claim.claim_line_items.each { |line| line.variant.stock_items.first&.set_count_on_hand(10) }

      result = Spree::Claims::Resolve.call(claim: claim, resolution: 'replacement')

      expect(result).to be_success
      expect(result.value).to be_resolved
    end
  end

  describe Spree::Claims::Deny do
    it 'denies an open claim with a reason' do
      claim = create_claim.value

      result = Spree::Claims::Deny.call(claim: claim, reason: 'Outside warranty')

      expect(result.value).to be_denied
      expect(result.value.memo).to include('Outside warranty')
    end
  end

  describe Spree::Claims::Cancel do
    it 'cancels an open claim' do
      claim = create_claim.value

      expect(Spree::Claims::Cancel.call(claim: claim).value).to be_canceled
    end

    it 'refuses a resolved claim' do
      claim = create(:approved_claim, store: store, order: order)
      Spree::Claims::Resolve.call(claim: claim, resolution: 'refund')

      expect(Spree::Claims::Cancel.call(claim: claim.reload)).to be_failure
    end
  end
end
