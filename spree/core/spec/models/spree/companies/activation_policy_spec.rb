require 'spec_helper'

RSpec.describe Spree::Companies::ActivationPolicy, type: :model do
  let(:store) { @default_store }
  let(:policy) { described_class.new }
  let(:customer) { create(:customer) }

  describe '#active?' do
    it 'activates every company by default' do
      expect(policy.active?(build(:company))).to be(true)
    end
  end

  describe '#pricing_access_code' do
    it 'asks a guest to sign in' do
      expect(policy.pricing_access_code(user: nil, store: store)).to eq('login_required')
    end

    it 'asks a customer without a company to register one' do
      expect(policy.pricing_access_code(user: customer, store: store)).to eq('company_required')
    end

    it 'answers nil for a member of an active company' do
      create(:company_membership, company: create(:company, store: store), customer: customer)

      expect(policy.pricing_access_code(user: customer, store: store)).to be_nil
    end

    # Customers are global, companies store-scoped: a membership elsewhere
    # must not unlock this store's prices.
    it 'does not count a membership in another store' do
      create(:company_membership, company: create(:company, store: create(:store)), customer: customer)

      expect(policy.pricing_access_code(user: customer, store: store)).to eq('company_required')
    end

    it 'requires standing over an ACTIVE company, not just any standing' do
      company = create(:company, store: store)
      create(:company_membership, company: company, customer: customer)

      with_company_activation_policy(inactive: [company]) do
        code = Spree.company_activation_policy_class.new.
               pricing_access_code(user: customer, store: store)

        expect(code).to eq('company_required')
      end
    end

    # A conforming policy suspends whole subtrees, so a member's standing
    # over a division must not slip past a suspended root.
    it 'stays gated when only the root of the tree is suspended' do
      root = create(:company, store: store)
      division = create(:company, store: store, kind: 'division', parent: root)
      create(:company_membership, company: division, customer: customer)

      with_company_activation_policy(inactive: [root]) do
        code = Spree.company_activation_policy_class.new.
               pricing_access_code(user: customer, store: store)

        expect(code).to eq('company_required')
      end
    end
  end

  describe '#first_active' do
    let(:companies) { create_list(:company, described_class::PAGE_SIZE + 2, store: store) }
    let(:relation) { Spree::Company.where(id: companies.map(&:id)) }

    it 'stops at the limit' do
      expect(policy.first_active(relation, limit: 2)).to eq(companies.first(2))
    end

    it 'pages past inactive companies to find active ones' do
      with_company_activation_policy(inactive: companies.first(described_class::PAGE_SIZE + 1)) do
        found = Spree.company_activation_policy_class.new.first_active(relation, limit: 2)

        expect(found).to eq([companies.last])
      end
    end
  end
end
