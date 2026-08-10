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

  # A placed order's tax has to stay explainable, so it answers from what it was
  # stamped with — otherwise adding this buyer to a company later would reach
  # back and exempt a sale that legitimately charged tax.
  describe 'a completed order' do
    let(:store) { @default_store }
    let(:order) { create(:completed_order_with_totals, store: store, customer: customer) }

    it 'does not acquire a company it was never placed for' do
      expect(order.b2b?).to be(false)

      location = create(:company_location, company: create(:company, store: store))
      create(:company_contact, company_location: location, customer: customer)

      expect(Spree::Order.find(order.id).b2b?).to be(false)
      expect(Spree::Order.find(order.id).company).to be_nil
    end

    it 'keeps the branch it was stamped with' do
      location = create(:company_location, company: create(:company, store: store))
      order.update_columns(company_location_id: location.id)

      expect(Spree::Order.find(order.id).resolved_company_location).to eq(location)
    end

    it 'does not lose it when the buyer later joins a second branch' do
      company = create(:company, store: store)
      location = create(:company_location, company: company)
      order.update_columns(company_location_id: location.id)
      create(:company_contact, company_location: location, customer: customer)
      create(:company_contact, company_location: create(:company_location, company: company), customer: customer)

      expect(Spree::Order.find(order.id).company).to eq(company)
    end
  end

  context 'included in Spree::Cart' do
    let(:record) { create(:cart, store: @default_store, customer: customer) }

    it_behaves_like 'a company host'
  end

  context 'included in Spree::Order' do
    let(:record) { create(:order, store: @default_store, customer: customer) }

    it_behaves_like 'a company host'
  end
end
