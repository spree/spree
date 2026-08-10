require 'spec_helper'

describe Spree::CompanyContact, type: :model do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }
  let(:location) { create(:company_location, company: company) }

  it 'reaches the company and store through its location' do
    contact = create(:company_contact, company_location: location)

    expect(contact.company).to eq(company)
    expect(contact.store).to eq(store)
  end

  it 'defaults the role to buyer' do
    expect(create(:company_contact, company_location: location).role).to eq('buyer')
  end

  it 'allows one contact per customer per location' do
    customer = create(:customer)
    create(:company_contact, company_location: location, customer: customer)

    duplicate = build(:company_contact, company_location: location, customer: customer)

    expect(duplicate).not_to be_valid
  end

  # A buyer purchasing for two branches is the case that makes selection
  # ambiguous — see the provisional resolution in Spree::Purchase::Company.
  it 'allows the same customer at several locations' do
    customer = create(:customer)
    create(:company_contact, company_location: location, customer: customer)
    other = create(:company_location, company: company)

    expect(build(:company_contact, company_location: other, customer: customer)).to be_valid
  end

  it 'is reachable from the customer' do
    customer = create(:customer)
    contact = create(:company_contact, company_location: location, customer: customer)

    expect(customer.company_contacts).to eq([contact])
    expect(customer.company_locations).to eq([location])
  end
end
