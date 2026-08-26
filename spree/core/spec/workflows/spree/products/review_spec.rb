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
      expect(product.rejection_reason).to eq('Photos are too dark')
    end

    # The panel offers "Edit reason" on a product already turned down, so the
    # workflow has to accept one — correcting the note is not a new decision.
    it 'rewrites the reason on one already rejected' do
      product.update!(status: 'proposed')
      Spree.product_reject_workflow.call(product: product, reason: 'Too dark')

      result = Spree.product_reject_workflow.call(product: product, reason: 'Needs a scale photo')

      expect(result).to be_success
      expect(product.reload.rejection_reason).to eq('Needs a scale photo')
    end

    # The reason is the operator's, and the seller can write their own
    # product's metadata — so it must not live anywhere the seller can reach.
    it 'survives the seller rewriting their own metadata' do
      product.update!(status: 'proposed')
      Spree.product_reject_workflow.call(product: product, reason: 'Photos are too dark')

      product.update!(metadata: { 'care' => 'wash cold' })

      expect(product.reload.rejection_reason).to eq('Photos are too dark')
    end

    it 'refuses a product nobody submitted' do
      result = Spree.product_reject_workflow.call(product: product)

      expect(result).not_to be_success
      expect(product.reload).to be_draft
    end
  end

  # The trail is what answers "who decided this, and when" — the product's
  # own status only says where it landed.
  describe 'the submission trail' do
    let(:staff) { create(:admin_user) }

    it 'records who submitted and who decided' do
      Spree.product_propose_workflow.call(product: product, submitted_by: staff)
      Spree.product_approve_workflow.call(product: product, reviewer: staff)

      submission = product.reload.latest_submission
      expect(submission).to be_approved
      expect(submission.submitted_by).to eq(staff)
      expect(submission.reviewed_by).to eq(staff)
      expect(submission.reviewed_at).to be_present
    end

    it 'keeps every decision rather than overwriting the last' do
      Spree.product_propose_workflow.call(product: product)
      Spree.product_reject_workflow.call(product: product, reason: 'Too dark')
      Spree.product_propose_workflow.call(product: product)
      Spree.product_approve_workflow.call(product: product)

      expect(product.reload.submissions.count).to eq(2)
      expect(product.submissions.latest_first.map(&:status)).to eq(%w[approved rejected])
    end

    # A blank reviewer must read as "this store does not review listings",
    # never as a decision whose author we failed to record.
    it 'marks an auto-approval as one' do
      stub_store_preferences(store, auto_approve_seller_products: true)

      Spree.product_propose_workflow.call(product: product)

      submission = product.reload.latest_submission
      expect(submission).to be_approved
      expect(submission.reviewed_by).to be_nil
      expect(submission).to be_auto_approved
    end

    # Otherwise a pending row means both "waiting on the marketplace" and
    # "the seller lost interest", which are different questions.
    it 'settles the open row when a seller takes the listing back' do
      Spree.product_propose_workflow.call(product: product)
      Spree.product_draft_workflow.call(product: product)

      expect(product.reload.latest_submission).to be_withdrawn
    end

    it 'leaves a product nobody submitted alone' do
      Spree.product_draft_workflow.call(product: product)

      expect(product.reload.submissions).to be_empty
    end

    # A rejection has already been decided. Inventing a `withdrawn` row for
    # it would bury the real decision under an entry nobody made.
    it 'does not withdraw a decision that was already made' do
      Spree.product_propose_workflow.call(product: product)
      Spree.product_reject_workflow.call(product: product, reason: 'Too dark')

      Spree.product_archive_workflow.call(product: product)

      expect(product.reload.submissions.count).to eq(1)
      expect(product.latest_submission).to be_rejected
      expect(product.latest_submission.review_note).to eq('Too dark')
    end
  end

  # Leaving review is a decision, and a decision has to record who made it.
  # A plain status write would put a product on sale anonymously.
  describe 'editing a product in review' do
    it 'refuses to move its status' do
      product.update!(status: 'proposed')

      result = Spree.product_update_workflow.call(product: product, attributes: { status: 'active' })

      expect(result).not_to be_success
      expect(product.reload).to be_proposed
    end

    it 'still allows ordinary edits' do
      product.update!(status: 'proposed')

      result = Spree.product_update_workflow.call(product: product, attributes: { name: 'Revised' })

      expect(result).to be_success
      expect(product.reload.name).to eq('Revised')
      expect(product).to be_proposed
    end

    # The CSV importer assigns attributes itself and hands the workflow an
    # already-dirty record. Reading the record rather than the payload
    # refused every re-imported row whose product happened to be in review.
    it 'allows a caller that assigned the status itself' do
      product.update!(status: 'proposed')
      product.status = 'active'

      result = Spree.product_update_workflow.call(product: product)

      expect(result).to be_success
      expect(product.reload).to be_active
    end
  end

  # These messages are shown to an operator, so a missing key does not fail
  # quietly — it renders `translation_missing` markup into the toast.
  it 'refuses with a real message rather than a missing-translation key' do
    result = Spree.product_approve_workflow.call(product: product)

    message = result.error.value.full_messages.join
    expect(message).not_to include('translation missing', 'translation_missing')
    expect(message).to include('not awaiting review')
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
