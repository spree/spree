require 'spec_helper'

# The review lifecycle for a seller's offer on a shared master-catalog
# product: the seller submits, the operator decides.
# See docs/plans/6.0-seller-master-catalog-listings.md.
RSpec.describe 'Spree::Variants review workflows' do
  let(:store) { Spree::Store.default }
  let(:seller) { create(:seller, :approved, store: store) }
  # A master product — no seller of its own, so a variant's seller column
  # means something and the row is an offer.
  let(:master) { create(:product, store: store, seller: nil, status: 'active') }
  let(:offer) do
    create(:variant, product: master, seller: seller, status: 'draft').tap do |variant|
      variant.set_price('USD', 10)
    end
  end

  describe 'Propose' do
    it 'submits a draft offer for review' do
      result = Spree.variant_propose_workflow.call(variant: offer)

      expect(result).to be_success
      expect(offer.reload).to be_proposed
    end

    it 'opens a pending submission naming the offer and its product' do
      Spree.variant_propose_workflow.call(variant: offer)

      submission = offer.reload.latest_submission
      expect(submission).to be_pending
      expect(submission.variant).to eq(offer)
      expect(submission.product).to eq(master)
    end

    # The trail is the offer's, never the product's: a master product carries
    # offers from several sellers and its own review history is separate.
    it 'keeps the offer trail off the product' do
      Spree.variant_propose_workflow.call(variant: offer)

      expect(master.reload.submissions).to be_empty
      expect(master.latest_submission).to be_nil
    end

    it 'refuses an offer already on sale' do
      offer.update!(status: 'active')

      result = Spree.variant_propose_workflow.call(variant: offer)

      expect(result).not_to be_success
      expect(offer.reload).to be_active
    end

    it 'refuses one already awaiting review' do
      offer.update!(status: 'proposed')

      expect(Spree.variant_propose_workflow.call(variant: offer)).not_to be_success
    end

    it 'resubmits a rejected offer' do
      offer.update!(status: 'rejected')

      expect(Spree.variant_propose_workflow.call(variant: offer)).to be_success
      expect(offer.reload).to be_proposed
    end

    # The buy box ranks on price and would drop a priceless row, so the
    # marketplace would be reviewing something nobody could buy.
    it 'refuses an offer with no price' do
      unpriced = create(:variant, product: master, seller: seller, status: 'draft')
      unpriced.prices.destroy_all

      result = Spree.variant_propose_workflow.call(variant: unpriced.reload)

      expect(result).not_to be_success
      expect(unpriced.reload).to be_draft
    end

    it 'goes straight on sale when the store approves offers automatically' do
      stub_store_preferences(store, auto_approve_seller_offers: true)

      result = Spree.variant_propose_workflow.call(variant: offer)

      expect(result).to be_success
      expect(offer.reload).to be_active
    end

    # A blank reviewer must read as "this store does not review offers",
    # never as a name somebody lost.
    it 'records that an auto-approval had no reviewer' do
      stub_store_preferences(store, auto_approve_seller_offers: true)

      Spree.variant_propose_workflow.call(variant: offer)

      expect(offer.reload.latest_submission).to be_auto_approved
    end

    it 'is not chained by the products preference' do
      stub_store_preferences(store, auto_approve_seller_products: true)

      Spree.variant_propose_workflow.call(variant: offer)

      expect(offer.reload).to be_proposed
    end
  end

  describe 'Approve' do
    let(:reviewer) { create(:admin_user) }

    before { Spree.variant_propose_workflow.call(variant: offer) }

    it 'puts the offer on sale and closes the submission' do
      result = Spree.variant_approve_workflow.call(variant: offer, reviewer: reviewer)

      expect(result).to be_success
      expect(offer.reload).to be_active

      submission = offer.latest_submission
      expect(submission).to be_approved
      expect(submission.reviewed_by).to eq(reviewer)
      expect(submission.reviewed_at).to be_present
    end

    it 'refuses an offer nobody submitted' do
      other = create(:variant, product: master, seller: seller, status: 'draft')

      expect(Spree.variant_approve_workflow.call(variant: other)).not_to be_success
    end
  end

  describe 'Reject' do
    let(:reviewer) { create(:admin_user) }

    before { Spree.variant_propose_workflow.call(variant: offer) }

    it 'sends the offer back with a reason the seller can read' do
      result = Spree.variant_reject_workflow.call(variant: offer, reason: 'Condition is wrong', reviewer: reviewer)

      expect(result).to be_success
      expect(offer.reload).to be_rejected
      expect(offer.rejection_reason).to eq('Condition is wrong')
      expect(offer.latest_submission.reviewed_by).to eq(reviewer)
    end

    # Correcting the note you gave a seller is not a second decision.
    it 'allows re-rejecting to correct the note' do
      Spree.variant_reject_workflow.call(variant: offer, reason: 'First', reviewer: reviewer)

      expect(Spree.variant_reject_workflow.call(variant: offer, reason: 'Second', reviewer: reviewer)).to be_success
      expect(offer.reload.rejection_reason).to eq('Second')
    end

    it 'stops answering with the reason once the offer moves on' do
      Spree.variant_reject_workflow.call(variant: offer, reason: 'Condition is wrong', reviewer: reviewer)
      Spree.variant_propose_workflow.call(variant: offer)

      expect(offer.reload.rejection_reason).to be_nil
    end
  end

  describe 'Draft and Archive' do
    before { Spree.variant_propose_workflow.call(variant: offer) }

    it 'withdraws the open submission when the seller takes the offer down' do
      expect(Spree.variant_draft_workflow.call(variant: offer)).to be_success

      expect(offer.reload).to be_draft
      expect(offer.latest_submission).to be_withdrawn
    end

    it 'withdraws the open submission when the seller archives the offer' do
      expect(Spree.variant_archive_workflow.call(variant: offer)).to be_success

      expect(offer.reload).to be_archived
      expect(offer.latest_submission).to be_withdrawn
    end

    # A rejected offer has already been decided; inventing a withdrawn row
    # for it would bury that decision under an entry nobody made.
    it 'leaves a decided submission alone' do
      Spree.variant_reject_workflow.call(variant: offer, reason: 'No')

      Spree.variant_draft_workflow.call(variant: offer)

      expect(offer.reload.latest_submission).to be_rejected
    end
  end

  describe 'Activate' do
    it 'puts a first-party variant on sale' do
      first_party = create(:variant, product: master, status: 'draft')

      expect(Spree.variant_activate_workflow.call(variant: first_party)).to be_success
      expect(first_party.reload).to be_active
    end

    # Otherwise an operator could put a seller's row on sale while recording
    # no decision and closing no submission.
    it "refuses a seller's offer, which goes on sale through Approve" do
      result = Spree.variant_activate_workflow.call(variant: offer)

      expect(result).not_to be_success
      expect(offer.reload).to be_draft
    end
  end

  describe 'Update' do
    it 'refuses a status write on an offer in review' do
      Spree.variant_propose_workflow.call(variant: offer)

      result = Spree.variant_update_workflow.call(variant: offer, attributes: { status: 'active' })

      expect(result).not_to be_success
      expect(offer.reload).to be_proposed
    end

    it 'allows an ordinary edit while in review' do
      Spree.variant_propose_workflow.call(variant: offer)

      result = Spree.variant_update_workflow.call(variant: offer, attributes: { sku: 'REVIEWED-1' })

      expect(result).to be_success
      expect(offer.reload.sku).to eq('REVIEWED-1')
      expect(offer).to be_proposed
    end
  end
end
