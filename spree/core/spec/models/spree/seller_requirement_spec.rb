require 'spec_helper'

RSpec.describe Spree::SellerRequirement, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, store: store) }

  describe 'validations' do
    it 'refuses a kind that is not registered' do
      requirement = build(:seller_requirement, store: store, type: 'Spree::SellerRequirements::Imaginary')

      expect(requirement).not_to be_valid
      expect(requirement.errors[:type]).to include('is not a registered seller requirement')
    end

    it 'allows a single-instance kind only once per store' do
      create(:accept_terms_requirement, store: store)
      duplicate = build(:accept_terms_requirement, store: store)

      expect(duplicate).not_to be_valid
    end

    it 'allows the same single-instance kind on another store' do
      create(:accept_terms_requirement, store: store)
      other = build(:accept_terms_requirement, store: create(:store))

      expect(other).to be_valid
    end

    it 'allows several rows of a kind whose meaning is the operator’s own words' do
      create(:document_requirement, store: store, name: 'Business registration')
      second = build(:document_requirement, store: store, name: 'Proof of insurance')

      expect(second).to be_valid
    end

    it 'requires a name on a kind that can appear more than once' do
      requirement = build(:document_requirement, store: store, name: nil)

      expect(requirement).not_to be_valid
      expect(requirement.errors[:name]).to be_present
    end
  end

  describe '#display_name' do
    it 'uses the operator’s wording when they wrote some' do
      requirement = build(:accept_terms_requirement, store: store, name: 'Agree to our rules')

      expect(requirement.display_name).to eq('Agree to our rules')
    end

    it 'falls back to the kind’s own name' do
      requirement = build(:accept_terms_requirement, store: store, name: nil)

      expect(requirement.display_name).to eq('Accept terms')
    end
  end

  describe '#latest_submission' do
    let(:requirement) { create(:attestation_requirement, store: store) }

    it 'returns the most recent row for that seller' do
      create(:seller_requirement_submission, seller: seller, requirement: requirement,
                                             status: 'rejected', created_at: 2.days.ago)
      newest = create(:seller_requirement_submission, seller: seller, requirement: requirement,
                                                      status: 'accepted', created_at: 1.hour.ago)

      expect(requirement.latest_submission(seller)).to eq(newest)
    end

    it 'ignores another seller’s submissions' do
      other_seller = create(:seller, store: store)
      create(:seller_requirement_submission, seller: other_seller, requirement: requirement)

      expect(requirement.latest_submission(seller)).to be_nil
    end
  end

  describe '#status_for' do
    let(:requirement) { create(:operator_review_requirement, store: store) }

    it 'is incomplete with nothing submitted' do
      expect(requirement.status_for(seller)).to eq('incomplete')
    end

    it 'is pending while someone still has to look at it' do
      create(:seller_requirement_submission, seller: seller, requirement: requirement, status: 'pending')

      expect(requirement.status_for(seller)).to eq('pending')
    end

    it 'is rejected when it was sent back' do
      create(:seller_requirement_submission, :rejected, seller: seller, requirement: requirement)

      expect(requirement.status_for(seller)).to eq('rejected')
    end

    it 'is complete once accepted' do
      create(:seller_requirement_submission, :accepted, seller: seller, requirement: requirement)

      expect(requirement.status_for(seller)).to eq('complete')
    end

    it 'is complete when the operator waived it' do
      create(:seller_requirement_submission, :waived, seller: seller, requirement: requirement)

      expect(requirement.status_for(seller)).to eq('complete')
    end
  end

  describe 'kind capabilities' do
    # These are what the generic workflows read instead of testing for a
    # class by name, so a gem's own kind gets the same treatment.
    it 'declares no file requirement by default' do
      expect(described_class.requires_file?).to be false
      expect(Spree::SellerRequirements::AcceptTerms.requires_file?).to be false
    end

    it 'lets a kind ask for a file' do
      expect(Spree::SellerRequirements::Document.requires_file?).to be true
    end

    it 'enforces the file on any kind that asks for one, not just Document' do
      custom_kind = Class.new(Spree::SellerRequirements::OperatorReview) do
        def self.name = 'Spree::SellerRequirements::InsuranceCertificate'
        def self.requires_file? = true
      end
      stub_const('Spree::SellerRequirements::InsuranceCertificate', custom_kind)
      allow(Spree).to receive(:seller_requirements).and_return(
        Spree.seller_requirements + [custom_kind]
      )

      requirement = custom_kind.create!(store: store, name: 'Insurance certificate')

      result = Spree::SellerRequirementSubmissions::Create.call(seller: seller, requirement: requirement)

      expect(result).to be_failure
      expect(result.error.value.full_messages.join).to match(/file is required/i)
    end
  end

  describe '.provision_defaults' do
    it 'writes the default checklist in order' do
      store.seller_requirements.destroy_all

      described_class.provision_defaults(store)

      expect(store.seller_requirements.reload.map(&:class)).to eq(
        [
          Spree::SellerRequirements::AcceptTerms,
          Spree::SellerRequirements::CompleteProfile,
          Spree::SellerRequirements::BillingAddress,
          Spree::SellerRequirements::ReturnsAddress,
          Spree::SellerRequirements::DeliveryMethod,
          Spree::SellerRequirements::MinimumProducts
        ]
      )
    end

    it 'does not duplicate what the store already has' do
      store.seller_requirements.destroy_all
      described_class.provision_defaults(store)

      expect { described_class.provision_defaults(store) }.not_to change { store.seller_requirements.reload.count }
    end
  end
end
