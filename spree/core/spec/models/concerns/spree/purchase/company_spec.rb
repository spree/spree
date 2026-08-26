require 'spec_helper'

RSpec.shared_examples 'a company host' do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }

  describe '#resolved_company' do
    it 'prefers the node named on the sale' do
      create(:company_membership, company: company, customer: record.customer)
      record.update!(company: company)

      expect(record.resolved_company).to eq(company)
    end

    context 'with no node named' do
      it 'resolves the one membership the buyer holds' do
        create(:company_membership, company: company, customer: record.customer)

        expect(record.reload.resolved_company).to eq(company)
      end

      # Guessing here would invoice one business for another's purchase.
      it 'refuses to choose when the buyer holds several memberships' do
        create(:company_membership, company: company, customer: record.customer)
        create(:company_membership, company: create(:company, store: store), customer: record.customer)

        expect(record.reload.resolved_company).to be_nil
      end

      it 'resolves nothing for a guest' do
        record.update!(customer: nil)

        expect(record.resolved_company).to be_nil
      end

      # Customers are global across stores, so a buyer can be a member at a
      # business this store does not trade as. Resolving to it would hand this
      # sale that company's registration and exemption certificates.
      it 'ignores a membership belonging to another store' do
        elsewhere = create(:company, store: create(:store))
        create(:company_membership, company: elsewhere, customer: record.customer)

        expect(record.reload.resolved_company).to be_nil
      end

      # The foreign membership must not count towards "holds several" either —
      # otherwise it would suppress a resolution that is genuinely unambiguous
      # within this store.
      it 'still resolves the one membership in this store when another store has one too' do
        create(:company_membership, company: company, customer: record.customer)
        elsewhere = create(:company, store: create(:store))
        create(:company_membership, company: elsewhere, customer: record.customer)

        expect(record.reload.resolved_company).to eq(company)
      end
    end
  end

  describe '#company_legal_entity' do
    it 'reads through the resolved node to its legal entity' do
      division = create(:company, store: store, kind: 'division', parent: company)
      create(:company_membership, company: division, customer: record.customer)

      expect(record.reload.company_legal_entity).to eq(company)
    end

    it 'is nil for a consumer sale' do
      expect(record.company_legal_entity).to be_nil
    end
  end

  describe 'the node must belong to the same store' do
    it 'refuses a node from another store' do
      elsewhere = create(:company, store: create(:store))

      record.company = elsewhere

      expect(record).not_to be_valid
      expect(record.errors[:company]).to be_present
    end
  end

  describe '#b2b?' do
    it 'is true once a node resolves' do
      create(:company_membership, company: company, customer: record.customer)

      expect(record.reload).to be_b2b
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

      create(:company_membership, company: create(:company, store: store), customer: customer)

      expect(Spree::Order.find(order.id).b2b?).to be(false)
      expect(Spree::Order.find(order.id).resolved_company).to be_nil
    end

    it 'keeps the node it was stamped with' do
      company = create(:company, store: store)
      order.update_columns(company_id: company.id)

      expect(Spree::Order.find(order.id).resolved_company).to eq(company)
    end

    it 'does not lose it when the buyer later joins a second company' do
      company = create(:company, store: store)
      order.update_columns(company_id: company.id)
      create(:company_membership, company: company, customer: customer)
      create(:company_membership, company: create(:company, store: store), customer: customer)

      expect(Spree::Order.find(order.id).resolved_company).to eq(company)
    end
  end

  # Standing is checked where the storefront writes — the cart. An order's
  # company arrives from completion (already validated) or from staff.
  describe 'standing over the named node' do
    let(:store) { @default_store }
    let(:company) { create(:company, store: store) }
    let(:cart) { create(:cart, store: store, customer: customer) }

    it 'refuses a cart naming a node the buyer has no standing over' do
      cart.company = company

      expect(cart).not_to be_valid
      expect(cart.errors[:company]).to be_present
    end

    it 'accepts a node the buyer is a member of' do
      create(:company_membership, company: company, customer: customer)
      cart.company = company

      expect(cart).to be_valid
    end

    # Membership at a node covers everything below it.
    it 'accepts a descendant of the membership node' do
      create(:company_membership, company: company, customer: customer)
      division = create(:company, store: store, kind: 'division', parent: company)
      cart.company = division

      expect(cart).to be_valid
    end

    it 'refuses an ancestor of the membership node' do
      division = create(:company, store: store, kind: 'division', parent: company)
      create(:company_membership, company: division, customer: customer)
      cart.company = company

      expect(cart).not_to be_valid
    end

    # Company ids are not secrets — they appear in responses and invite links
    # — so a token-authorized guest cart must not be able to claim one and
    # ride its tax exemptions and catalog prices through checkout.
    it 'refuses a company on a guest cart' do
      guest_cart = create(:cart, store: store, customer: nil)
      guest_cart.company = company

      expect(guest_cart).not_to be_valid
      expect(guest_cart.errors[:company]).to be_present
    end

    it 'does not re-run once the node is stamped' do
      create(:company_membership, company: company, customer: customer)
      cart.update!(company: company)
      customer.company_memberships.destroy_all

      cart.customer_note = 'unrelated change'

      expect(cart).to be_valid
    end

    it 'lets staff name a node on an order without a membership' do
      order = create(:order, store: store, customer: customer)
      order.company = company

      expect(order).to be_valid
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
