require 'spec_helper'

describe Spree::CompanyMembership, type: :model do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }
  let(:customer) { create(:customer) }

  it 'is unique per customer and node' do
    create(:company_membership, company: company, customer: customer)

    expect(build(:company_membership, company: company, customer: customer)).not_to be_valid
  end

  it 'allows the same customer at another node' do
    create(:company_membership, company: company, customer: customer)

    expect(build(:company_membership, company: create(:company, store: store), customer: customer)).to be_valid
  end

  it 'defaults the cosmetic role label' do
    expect(described_class.new.role).to eq('buyer')
  end

  it 'reaches the store through the company' do
    membership = create(:company_membership, company: company, customer: customer)

    expect(membership.store).to eq(store)
  end

  describe 'standing' do
    it 'covers the membership node and its subtree' do
      division = create(:company, store: store, kind: 'division', parent: company)
      create(:company_membership, company: company, customer: customer)

      expect(customer.standing_for?(company)).to be(true)
      expect(customer.standing_for?(division)).to be(true)
      expect(customer.company_standing(store: store)).to contain_exactly(company, division)
    end

    it 'does not cover ancestors or siblings' do
      division = create(:company, store: store, kind: 'division', parent: company)
      sibling = create(:company, store: store, kind: 'division', parent: company)
      create(:company_membership, company: division, customer: customer)

      expect(customer.standing_for?(company)).to be(false)
      expect(customer.standing_for?(sibling)).to be(false)
    end

    it 'is evaluated per store' do
      elsewhere = create(:company, store: create(:store))
      create(:company_membership, company: elsewhere, customer: customer)

      expect(customer.company_standing(store: store)).to be_empty
    end
  end
end
