require 'spec_helper'

RSpec.describe 'seller requirement kinds', type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, store: store) }

  describe Spree::SellerRequirements::AcceptTerms do
    let(:requirement) { create(:accept_terms_requirement, store: store) }

    it 'is unmet until the seller accepts' do
      expect(requirement.satisfied?(seller)).to be false
    end

    it 'is met once they have' do
      seller.update!(terms_accepted_at: Time.current)

      expect(requirement.satisfied?(seller)).to be true
    end

    it 'asks again when the terms were rewritten after the seller accepted' do
      seller.update!(terms_accepted_at: 1.year.ago)
      requirement.update!(preferred_terms_effective_from: 1.month.ago.iso8601)

      expect(requirement.satisfied?(seller)).to be false
    end

    # A cut-off that is not a fixed instant would move on its own: parse turns
    # "09:00" into nine o'clock today, so a seller compliant yesterday would
    # fall out overnight.
    it 'refuses a time with no date, which would move every midnight' do
      requirement.preferred_terms_effective_from = '09:00'

      expect(requirement).not_to be_valid
      expect(requirement.errors.full_messages.join).to match(/not a date/i)
    end

    it 'refuses a relative date' do
      requirement.preferred_terms_effective_from = 'tomorrow'

      expect(requirement).not_to be_valid
    end

    # The operator types a date meaning midnight where they trade. Reading it
    # in the server's zone would move the deadline by hours for every store
    # that is not on it.
    it 'reads the date in the store’s timezone, not the server’s' do
      stub_store_preferences(store, timezone: 'Asia/Tokyo')
      requirement.update!(preferred_terms_effective_from: '2026-01-01')

      expect(requirement.effective_from).to eq(Time.find_zone('Asia/Tokyo').iso8601('2026-01-01'))
      expect(requirement.effective_from.utc).to eq(Time.utc(2025, 12, 31, 15, 0, 0))
    end

    it 'falls back when the store carries a timezone nothing recognizes' do
      stub_store_preferences(store, timezone: 'Not/AZone')
      requirement.update!(preferred_terms_effective_from: '2026-01-01')

      expect(requirement.effective_from).to be_present
    end

    it 'takes a date and a full timestamp' do
      requirement.preferred_terms_effective_from = '2026-01-01'
      expect(requirement).to be_valid

      requirement.preferred_terms_effective_from = '2026-01-01T09:00:00Z'
      expect(requirement).to be_valid
    end

    it 'stays met for a seller who accepted the current terms' do
      requirement.update!(preferred_terms_effective_from: 1.month.ago.iso8601)
      seller.update!(terms_accepted_at: 1.day.ago)

      expect(requirement.satisfied?(seller)).to be true
    end
  end

  describe Spree::SellerRequirements::CompleteProfile do
    let(:requirement) { create(:complete_profile_requirement, store: store) }

    it 'asks for the fields the operator ticked' do
      requirement.update!(preferred_require_about: true, preferred_require_logo: false,
                          preferred_require_contact_email: false)

      expect(requirement.satisfied?(seller)).to be false

      seller.update!(about: 'We sell things.')

      expect(requirement.satisfied?(seller)).to be true
    end

    it 'ignores the fields they did not' do
      requirement.update!(preferred_require_about: false, preferred_require_logo: false,
                          preferred_require_cover_photo: false, preferred_require_contact_email: false)

      expect(requirement.satisfied?(seller)).to be true
    end
  end

  describe Spree::SellerRequirements::BillingAddress do
    let(:requirement) { create(:billing_address_requirement, store: store) }

    it 'is met once an address is saved' do
      expect(requirement.satisfied?(seller)).to be false

      seller.update!(billing_address: create(:address))

      expect(requirement.satisfied?(seller.reload)).to be true
    end
  end

  describe Spree::SellerRequirements::MinimumProducts do
    let(:requirement) { create(:minimum_products_requirement, store: store) }

    it 'counts the seller’s own listings' do
      expect(requirement.satisfied?(seller)).to be false

      create(:product, store: store, seller: seller)

      expect(requirement.satisfied?(seller.reload)).to be true
    end

    it 'asks for as many as the operator configured' do
      requirement.update!(preferred_minimum_count: 2)
      create(:product, store: store, seller: seller)

      expect(requirement.satisfied?(seller.reload)).to be false
    end

    it 'asks for nothing when configured to zero' do
      requirement.update!(preferred_minimum_count: 0)

      expect(requirement.satisfied?(seller)).to be true
    end
  end

  describe Spree::SellerRequirements::RequiredCustomFields do
    let(:requirement) { create(:required_custom_fields_requirement, store: store) }

    it 'asks nothing while the operator has named no fields' do
      expect(requirement.satisfied?(seller)).to be true
    end

    it 'is unmet until the chosen field has a value' do
      definition = create(:custom_field_definition, resource_type: 'Spree::Seller',
                                                    namespace: 'compliance', key: 'vat_number')
      requirement.update!(custom_field_definitions: [definition])

      expect(requirement.satisfied?(seller)).to be false

      seller.custom_fields.create!(custom_field_definition: definition, value: 'PL1234567890')

      expect(requirement.satisfied?(seller.reload)).to be true
    end

    it 'refuses a field defined for something other than a seller' do
      product_field = create(:custom_field_definition, resource_type: 'Spree::Product')

      link = requirement.seller_requirement_custom_fields.new(custom_field_definition: product_field)

      expect(link).not_to be_valid
      expect(link.errors[:custom_field_definition].join).to match(/defined for sellers/i)
    end

    it 'forgets a field the operator deleted rather than asking for it forever' do
      definition = create(:custom_field_definition, resource_type: 'Spree::Seller')
      requirement.update!(custom_field_definitions: [definition])

      definition.destroy

      expect(requirement.reload.custom_field_definitions).to be_empty
      expect(requirement.satisfied?(seller)).to be true
    end
  end

  describe Spree::SellerRequirements::Document do
    let(:requirement) { create(:document_requirement, store: store) }

    it 'is not met by an accepted submission carrying no file' do
      create(:seller_requirement_submission, :accepted, seller: seller, requirement: requirement)

      expect(requirement.satisfied?(seller)).to be false
    end

    it 'is met by an accepted submission with a file' do
      create(:seller_requirement_submission, :accepted, :with_file, seller: seller, requirement: requirement)

      expect(requirement.satisfied?(seller)).to be true
    end

    it 'is met by a waiver, which is the point of one' do
      create(:seller_requirement_submission, :waived, seller: seller, requirement: requirement)

      expect(requirement.satisfied?(seller)).to be true
    end
  end
end
