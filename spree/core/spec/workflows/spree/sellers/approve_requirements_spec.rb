require 'spec_helper'

RSpec.describe Spree::Sellers::Approve, 'onboarding requirements' do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :onboarding, store: store) }

  before { store.seller_requirements.destroy_all }

  it 'refuses while something required is unmet' do
    create(:accept_terms_requirement, store: store)

    result = described_class.call(seller: seller)

    expect(result).to be_failure
    expect(result.error.value.full_messages.join).to include('Accept terms')
    expect(seller.reload).not_to be_approved
  end

  it 'lets the operator step over it deliberately' do
    create(:accept_terms_requirement, store: store)

    result = described_class.call(seller: seller, override_requirements: true)

    expect(result).to be_success
    expect(seller.reload).to be_approved
  end

  it 'announces what was outstanding when the operator overrode it' do
    create(:accept_terms_requirement, store: store)
    workflow = described_class.new
    published = nil
    allow(seller).to receive(:publish_event) do |name, _payload, metadata|
      published = metadata if name == 'seller.approved'
    end

    workflow.perform(seller: seller, override_requirements: true)

    expect(published[:requirements_overridden]).to be true
    expect(published[:unmet_requirements]).to include('Accept terms')
  end

  it 'goes through with no override once the checklist is done' do
    create(:accept_terms_requirement, store: store)
    seller.update!(terms_accepted_at: Time.current)

    expect(described_class.call(seller: seller.reload)).to be_success
  end

  # Sellers::Reject refuses an approved seller, so a rejected one is always an
  # applicant who never got in. Approving them is the original admission
  # decision, not the undoing of one.
  it 'measures a rejected applicant, who was never admitted in the first place' do
    create(:accept_terms_requirement, store: store)
    rejected = create(:seller, store: store, status: 'rejected')

    result = described_class.call(seller: rejected)

    expect(result).to be_failure
    expect(rejected.reload).not_to be_approved
  end

  it 'lets the operator override a rejected applicant deliberately' do
    create(:accept_terms_requirement, store: store)
    rejected = create(:seller, store: store, status: 'rejected')

    expect(described_class.call(seller: rejected, override_requirements: true)).to be_success
    expect(rejected.reload).to be_approved
  end

  it 'does not re-measure a suspended seller being reinstated' do
    create(:accept_terms_requirement, store: store)
    suspended = create(:seller, :suspended, store: store)

    expect(described_class.call(seller: suspended)).to be_success
    expect(suspended.reload).to be_approved
  end
end
