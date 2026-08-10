require 'spec_helper'

RSpec.shared_examples 'a company host' do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }
  let(:location) { create(:company_location, company: company) }

  describe '#resolved_company_location' do
    it 'prefers the branch named on the sale' do
      record.update!(company_location: location)

      expect(record.resolved_company_location).to eq(location)
    end

    context 'with no branch named' do
      it 'resolves the one branch the buyer acts for' do
        create(:company_contact, company_location: location, customer: record.customer)

        expect(record.reload.resolved_company_location).to eq(location)
      end

      # Guessing here would invoice one business for another's purchase.
      it 'refuses to choose when the buyer acts for several' do
        create(:company_contact, company_location: location, customer: record.customer)
        create(:company_contact, company_location: create(:company_location, company: company),
                                 customer: record.customer)

        expect(record.reload.resolved_company_location).to be_nil
      end

      it 'resolves nothing for a guest' do
        record.update!(customer: nil)

        expect(record.resolved_company_location).to be_nil
      end
    end
  end

  describe '#company' do
    it 'derives from the resolved branch' do
      record.update!(company_location: location)

      expect(record.company).to eq(company)
    end

    it 'is nil for a consumer sale' do
      expect(record.company).to be_nil
    end
  end

  describe '#b2b?' do
    it 'is true once a branch resolves' do
      record.update!(company_location: location)

      expect(record).to be_b2b
    end

    it 'is false otherwise' do
      expect(record).not_to be_b2b
    end
  end
end

RSpec.describe Spree::Purchase::Company do
  let(:customer) { create(:customer) }

  context 'included in Spree::Cart' do
    let(:record) { create(:cart, store: @default_store, customer: customer) }

    it_behaves_like 'a company host'
  end

  context 'included in Spree::Order' do
    let(:record) { create(:order, store: @default_store, customer: customer) }

    it_behaves_like 'a company host'
  end
end
