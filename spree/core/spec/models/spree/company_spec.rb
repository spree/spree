require 'spec_helper'

describe Spree::Company, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }

  describe 'store binding' do
    it 'refuses to move between stores once saved' do
      company = create(:company, store: store)

      company.store = create(:store)

      expect(company).not_to be_valid
    end

    it 'is reachable through the store' do
      company = create(:company, store: store)

      expect(store.companies).to include(company)
      expect(Spree::Company.for_store(store)).to include(company)
    end
  end

  # The former external_id column moved to Spree::ExternalReference so a company
  # can be known to an ERP and a CRM at once (docs/plans/6.0-third-party-pricing-inventory.md).
  describe 'external references' do
    it 'is unique per store and system' do
      create(:company, store: store).set_external_id('erp', 'ACME')
      duplicate = create(:company, store: store)

      expect { duplicate.set_external_id('erp', 'ACME') }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'allows the same reference in another store' do
      create(:company, store: store).set_external_id('erp', 'ACME')
      elsewhere = create(:company, store: create(:store))

      expect(elsewhere.set_external_id('erp', 'ACME')).to be_persisted
    end

    it 'lets several companies carry no reference' do
      create(:company, store: store)

      expect(build(:company, store: store)).to be_valid
    end

    it 'carries one identity per external system' do
      company = create(:company, store: store)
      company.set_external_id('erp', 'ACME')
      company.set_external_id('crm', 'CUST-1')

      expect(company.external_id_for('erp')).to eq('ACME')
      expect(company.external_id_for('crm')).to eq('CUST-1')
    end
  end

  describe 'contacts' do
    it 'collects the contacts of every location' do
      company = create(:company, store: store)
      first = create(:company_contact, company_location: create(:company_location, company: company))
      second = create(:company_contact, company_location: create(:company_location, company: company))

      expect(company.company_contacts).to contain_exactly(first, second)
    end
  end

  describe 'metadata' do
    # Spree::Metadata would shadow the real column with a virtual
    # private_metadata and lose the write — see docs/plans/decisions.md.
    it 'persists to the single metadata column' do
      company = create(:company, store: store, metadata: { 'erp_ref' => 'X-1' })

      expect(company.reload.metadata['erp_ref']).to eq('X-1')
    end
  end

  it 'destroys its locations and their contacts' do
    company = create(:company, store: store)
    create(:company_contact, company_location: create(:company_location, company: company))

    expect { company.destroy }.to change(Spree::CompanyLocation, :count).by(-1).
      and change(Spree::CompanyContact, :count).by(-1)
  end
end
