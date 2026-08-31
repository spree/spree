require 'spec_helper'

RSpec.describe Spree::Companies::Register do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }

  def register(**arguments)
    described_class.call(store: store, customer: customer, name: 'Acme Trading', **arguments)
  end

  it 'founds a root company with the founder as its first member' do
    result = register

    expect(result).to be_success
    company = result.value
    expect(company).to be_persisted
    expect(company.kind).to eq('company')
    expect(company.parent_id).to be_nil
    expect(company.store).to eq(store)
    expect(company.memberships.map(&:customer)).to eq([customer])
  end

  it 'stores the registration answers under metadata' do
    result = register(registration: { vat_number: 'PL123', trade: 'electronics' })

    expect(result.value.metadata['registration']).to eq(
      'vat_number' => 'PL123', 'trade' => 'electronics'
    )
  end

  it 'keeps registration answers beside other metadata' do
    result = register(metadata: { source: 'campaign' }, registration: { trade: 'tools' })

    expect(result.value.metadata).to eq(
      'source' => 'campaign', 'registration' => { 'trade' => 'tools' }
    )
  end

  it 'publishes company.registered' do
    allow(Spree::Events).to receive(:enabled?).and_return(true)
    allow(Spree::Events).to receive(:publish)

    register

    expect(Spree::Events).to have_received(:publish).with('company.registered', anything, anything)
  end

  it 'fails on an invalid company without creating anything' do
    result = described_class.call(store: store, customer: customer, name: '')

    expect(result).to be_failure
    expect(store.companies.count).to eq(0)
    expect(customer.company_memberships.count).to eq(0)
  end

  describe 'the one-root guard' do
    it 'refuses a second founding by the same customer' do
      register

      result = register

      expect(result).to be_failure
      expect(result.error.to_s).to include('already registered a company')
      expect(store.companies.roots.count).to eq(1)
    end

    it 'refuses even under a different name' do
      register

      result = described_class.call(store: store, customer: customer, name: 'Other Business')

      expect(result).to be_failure
    end

    # Being invited into somebody's organization is not having founded one.
    it 'lets an invited division member found their own business' do
      root = create(:company, store: store)
      division = create(:company, store: store, kind: 'division', parent: root)
      create(:company_membership, company: division, customer: customer)

      expect(register).to be_success
    end

    it 'refuses a customer already holding a membership on any root' do
      create(:company_membership, company: create(:company, store: store), customer: customer)

      expect(register).to be_failure
    end

    # Companies are store-scoped; a business registered with another store
    # does not stop this one.
    it 'ignores a root founded in another store' do
      other_store = create(:store)
      other_root = create(:company, store: other_store)
      create(:company_membership, company: other_root, customer: customer)

      expect(register).to be_success
    end
  end

  describe 'the validate hook' do
    before { Spree.hooks.clear! }
    after { Spree.hooks.clear! }

    it 'lets a handler veto the registration before anything persists' do
      Spree.hooks.register('companies.register.validate') do |workflow|
        workflow.errors.add(:base, 'screening failed')
        workflow.reject!
      end

      result = register

      expect(result).to be_failure
      expect(result.error.to_s).to include('screening failed')
      expect(store.companies.count).to eq(0)
    end

    it 'exposes the built, unsaved company to handlers' do
      seen = nil
      Spree.hooks.register('companies.register.validate') do |workflow|
        seen = [workflow.company.name, workflow.company.persisted?]
      end

      register

      expect(seen).to eq(['Acme Trading', false])
    end

    it 'does not fire when an invitation is accepted' do
      fired = false
      Spree.hooks.register('companies.register.validate') { |_workflow| fired = true }
      invitation = create(:company_invitation, company: create(:company, store: store))

      Spree::CompanyInvitations::Accept.call(
        invitation: invitation,
        customer_attributes: { password: 'password123', password_confirmation: 'password123' }
      )

      expect(fired).to be(false)
    end
  end
end
