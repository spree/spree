require 'spec_helper'

RSpec.describe Spree::Sellers::Requirements do
  let(:store) { @default_store }
  let(:seller) { create(:seller, store: store) }

  subject(:requirements) { described_class.new(seller.reload) }

  before { store.seller_requirements.destroy_all }

  describe '#statuses' do
    it 'is empty when the marketplace asks for nothing' do
      expect(requirements.statuses).to be_empty
      expect(requirements).to be_met
    end

    it 'follows the operator’s order' do
      second = create(:billing_address_requirement, store: store)
      first = create(:accept_terms_requirement, store: store)
      first.move_to_top

      expect(requirements.statuses.map(&:kind)).to eq(%w[accept_terms billing_address])
      expect(second.reload.position).to be > first.reload.position
    end

    it 'leaves out requirements the operator switched off' do
      create(:accept_terms_requirement, store: store, active: false)

      expect(requirements.statuses).to be_empty
    end

    it 'carries the submission behind a status' do
      requirement = create(:operator_review_requirement, store: store)
      submission = create(:seller_requirement_submission, seller: seller, requirement: requirement)

      expect(requirements.statuses.first.submission).to eq(submission)
    end
  end

  describe '#blocking' do
    it 'holds only the required ones that are unmet' do
      create(:accept_terms_requirement, store: store, required: true)
      create(:billing_address_requirement, store: store, required: false)

      expect(requirements.blocking.map(&:kind)).to eq(['accept_terms'])
      expect(requirements).not_to be_met
    end

    it 'is empty once every required one is met' do
      create(:accept_terms_requirement, store: store)
      seller.update!(terms_accepted_at: Time.current)

      expect(described_class.new(seller.reload).blocking).to be_empty
    end
  end

  describe '#progress' do
    it 'counts optional requirements too, so it does not jump' do
      create(:accept_terms_requirement, store: store, required: true)
      create(:billing_address_requirement, store: store, required: false)
      seller.update!(terms_accepted_at: Time.current)

      expect(described_class.new(seller.reload).progress).to eq(done: 1, total: 2, percentage: 50)
    end

    it 'reads as finished when nothing is asked' do
      expect(requirements.progress).to eq(done: 0, total: 0, percentage: 100)
    end
  end
end
