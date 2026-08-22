require 'spec_helper'

describe Spree::CompanyLocation, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }

  it 'reaches the store through its company' do
    location = create(:company_location, company: company)

    expect(location.store).to eq(store)
    expect(location.store_id).to eq(store.id)
  end

  describe 'addresses' do
    it 'creates them inline from nested attributes' do
      location = create(:company_location, company: company,
                                           billing_address_attributes: build(:address).attributes.except('id', 'type', 'created_at', 'updated_at'))

      expect(location.billing_address).to be_present
    end

    # The branch owns its address rows, so nothing is left behind and nothing
    # shared is taken away.
    it 'destroys its own address rows with it' do
      location = create(:company_location, company: company,
                                           billing_address: create(:business_address),
                                           shipping_address: create(:business_address))

      expect { location.destroy }.to change(Spree::Address, :count).by(-2)
    end
  end

  it 'destroys its contacts' do
    location = create(:company_location, company: company)
    create(:company_contact, company_location: location)

    expect { location.destroy }.to change(Spree::CompanyContact, :count).by(-1)
  end

  it 'exposes the customers who buy for it' do
    location = create(:company_location, company: company)
    customer = create(:customer)
    create(:company_contact, company_location: location, customer: customer)

    expect(location.customers).to eq([customer])
  end
end
