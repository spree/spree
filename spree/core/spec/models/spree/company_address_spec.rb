require 'spec_helper'

describe Spree::CompanyAddress, type: :model do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }

  it 'owns its address row outright' do
    entry = create(:company_address, company: company)

    expect { entry.destroy }.to change(Spree::Address, :count).by(-1)
  end

  it 'accepts a nested address hash under the read name' do
    entry = create(:company_address, company: company)
    entry.update!(address: { city: 'Springfield' })

    expect(entry.reload.address.city).to eq('Springfield')
  end

  describe 'defaults' do
    it 'keeps at most one default billing entry per node' do
      first = create(:company_address, company: company, default_billing: true)
      second = create(:company_address, company: company, default_billing: true)

      expect(first.reload.default_billing).to be(false)
      expect(second.reload.default_billing).to be(true)
    end

    it 'keeps at most one default shipping entry per node' do
      first = create(:company_address, company: company, default_shipping: true)
      second = create(:company_address, company: company, default_shipping: true)

      expect(first.reload.default_shipping).to be(false)
      expect(second.reload.default_shipping).to be(true)
    end

    it 'leaves another node untouched' do
      other = create(:company_address, company: create(:company, store: store), default_billing: true)
      create(:company_address, company: company, default_billing: true)

      expect(other.reload.default_billing).to be(true)
    end
  end
end
