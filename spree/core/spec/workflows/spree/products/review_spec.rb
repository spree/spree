require 'spec_helper'

# The marketplace review lifecycle: a seller submits, the operator decides.
# See docs/plans/6.0-seller-product-submission.md.
RSpec.describe 'Spree::Products review workflows' do
  let(:store) { Spree::Store.default }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:product) { create(:product, store: store, seller: seller, status: 'draft') }

  describe 'Propose' do
    it 'submits a draft for review' do
      result = Spree.product_propose_workflow.call(product: product)

      expect(result).to be_success
      expect(product.reload).to be_proposed
    end

    it 'refuses a product already on sale' do
      product.update!(status: 'active')

      result = Spree.product_propose_workflow.call(product: product)

      expect(result).not_to be_success
      expect(product.reload).to be_active
    end

    # Auto-approval makes this the sharp one: without the guard an archived
    # listing went straight back on sale with nobody reviewing it.
    it 'refuses an archived product' do
      product.update!(status: 'archived')

      result = Spree.product_propose_workflow.call(product: product)

      expect(result).not_to be_success
      expect(product.reload).to be_archived
    end

    it 'refuses one already awaiting review' do
      product.update!(status: 'proposed')

      expect(Spree.product_propose_workflow.call(product: product)).not_to be_success
    end

    it 'resubmits a rejected product' do
      product.update!(status: 'rejected')

      expect(Spree.product_propose_workflow.call(product: product)).to be_success
      expect(product.reload).to be_proposed
    end

    # The store that does not review listings says so once, rather than
    # leaving an operator to approve every submission by hand.
    it 'goes straight on sale when the store approves automatically' do
      stub_store_preferences(store, auto_approve_seller_products: true)

      result = Spree.product_propose_workflow.call(product: product)

      expect(result).to be_success
      expect(product.reload).to be_active
    end
  end

  describe 'Approve' do
    it 'puts a submitted product on sale' do
      product.update!(status: 'proposed')

      result = Spree.product_approve_workflow.call(product: product)

      expect(result).to be_success
      expect(product.reload).to be_active
    end

    # Approving is closing a review somebody opened, not a way to publish
    # anything at all — that is what Activate is for.
    it 'refuses a product nobody submitted' do
      result = Spree.product_approve_workflow.call(product: product)

      expect(result).not_to be_success
      expect(product.reload).to be_draft
    end
  end

  describe 'Reject' do
    it 'turns a submitted product down and keeps the reason' do
      product.update!(status: 'proposed')

      result = Spree.product_reject_workflow.call(product: product, reason: 'Photos are too dark')

      expect(result).to be_success
      expect(product.reload).to be_rejected
      expect(product.metadata['rejection_reason']).to eq('Photos are too dark')
    end

    it 'refuses a product nobody submitted' do
      result = Spree.product_reject_workflow.call(product: product)

      expect(result).not_to be_success
      expect(product.reload).to be_draft
    end
  end

  # A product under review is not on sale. The storefront scope keys off
  # `active` alone, so this holds for any status we add without touching it.
  it 'keeps products under review out of the storefront' do
    %w[proposed rejected].each do |status|
      product.update!(status: status)

      expect(Spree::Product.active.where(id: product.id)).to be_empty
    end
  end
end
