require 'spec_helper'

RSpec.describe Spree::Sellers::SubmitForReview do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :onboarding, store: store) }

  before { store.seller_requirements.destroy_all }

  it 'refuses while a required requirement is unmet, and says which' do
    create(:accept_terms_requirement, store: store)

    result = described_class.call(seller: seller)

    expect(result).to be_failure
    expect(result.error.value.full_messages.join).to include('Accept terms')
    expect(seller.reload).to be_onboarding
  end

  it 'ignores optional requirements' do
    create(:accept_terms_requirement, store: store, required: false)

    result = described_class.call(seller: seller)

    expect(result).to be_success
    expect(seller.reload).to be_ready_for_review
  end

  it 'goes through once every required requirement is met' do
    create(:accept_terms_requirement, store: store)
    seller.update!(terms_accepted_at: Time.current)

    result = described_class.call(seller: seller.reload)

    expect(result).to be_success
    expect(seller.reload).to be_ready_for_review
  end

  it 'refuses a seller who is not onboarding' do
    approved = create(:seller, :approved, store: store)

    expect(described_class.call(seller: approved)).to be_failure
  end

  it 'admits the seller outright when the marketplace asks it to' do
    stub_store_preferences(store, auto_approve_sellers: true)

    expect(described_class.call(seller: seller)).to be_success
    expect(seller.reload).to be_approved
  end

  it 'does not admit outright while something required is missing' do
    stub_store_preferences(store, auto_approve_sellers: true)
    create(:accept_terms_requirement, store: store)

    expect(described_class.call(seller: seller)).to be_failure
    expect(seller.reload).to be_onboarding
  end
end
