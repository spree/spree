require 'spec_helper'

RSpec.describe Spree::Invoice, type: :model do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }

  describe '.issuer_for' do
    it 'is the store for a first-party order' do
      expect(described_class.issuer_for(order)).to eq(store)
    end

    it "is the seller for a seller's order" do
      seller = create(:seller, store: store)
      order.update_columns(seller_id: seller.id)

      expect(described_class.issuer_for(order.reload)).to eq(seller)
    end

    it 'is the store for a platform-remitted seller' do
      seller = create(:seller, store: store, tax_remittance: 'platform')
      order.update_columns(seller_id: seller.id)

      expect(described_class.issuer_for(order.reload)).to eq(store)
    end
  end

  describe 'validations' do
    it 'is valid from the factory' do
      expect(build(:invoice, order: order)).to be_valid
    end

    it 'requires a file' do
      invoice = build(:invoice, order: order)
      invoice.file.detach

      expect(invoice).not_to be_valid
      expect(invoice.errors[:file]).to be_present
    end

    it 'refuses a file that is not a PDF, whatever it is called' do
      invoice = build(:invoice, order: order)
      invoice.file.attach(io: StringIO.new('<html><script>alert(1)</script></html>'), filename: 'invoice.pdf', content_type: 'application/pdf')

      expect(invoice).not_to be_valid
      expect(invoice.errors.details[:file]).to include(error: :spree_content_type_not_allowed)
    end

    it 'belongs to exactly one of an order and a seller payout' do
      invoice = build(:invoice, order: order, seller_payout: create(:seller_payout, store: store))

      expect(invoice).not_to be_valid
      expect(invoice.errors.details[:base]).to include(error: :invoice_parent_required)
    end

    it "refuses an issuer other than the order's" do
      seller = create(:seller, store: store)
      invoice = build(:invoice, order: order, issuer: seller)

      expect(invoice).not_to be_valid
      expect(invoice.errors.details[:issuer]).to include(error: :invoice_issuer_mismatch)
    end

    it 'keeps numbers unique per issuer and kind' do
      create(:invoice, order: order, number: 'FV/1')

      expect(build(:invoice, order: order, number: 'FV/1')).not_to be_valid
      expect(build(:invoice, :credit_note, order: order, number: 'FV/1')).to be_valid
    end

    it 'needs a credit note to carry a total of zero or less, and anything else zero or more' do
      expect(build(:invoice, order: order, total: -5)).not_to be_valid
      expect(build(:invoice, :credit_note, order: order, total: 5)).not_to be_valid
    end

    it 'lets only a credit note or an invoice replacing a receipt point at an original' do
      original = create(:invoice, order: order)
      receipt = create(:invoice, :receipt, order: order)
      credit_note = create(:invoice, :credit_note, order: order, original_invoice: original)

      expect(build(:invoice, order: order, original_invoice: receipt)).to be_valid
      expect(build(:invoice, order: order, original_invoice: original)).not_to be_valid
      expect(build(:invoice, :credit_note, order: order, original_invoice: credit_note)).not_to be_valid
      expect(build(:invoice, :credit_note, order: order, original_invoice_id: 0)).not_to be_valid
    end

    it 'refuses an original invoice from another order' do
      other = create(:invoice)
      credit_note = build(:invoice, :credit_note, order: order, original_invoice: other)

      expect(credit_note).not_to be_valid
      expect(credit_note.errors[:original_invoice]).to be_present
    end
  end

  describe 'immutability' do
    let!(:invoice) { create(:invoice, order: order) }

    it 'refuses changes to what the invoice says' do
      expect(invoice.update(number: 'CHANGED', total: 1)).to be(false)
      expect(invoice.errors.details[:number]).to include(error: :invoice_immutable)
    end

    it 'accepts metadata' do
      expect(invoice.update(metadata: { 'erp' => '42' })).to be(true)
    end

    it 'records when it was first sent, and keeps that date when sent again' do
      invoice.mark_sent!
      first_sent_at = invoice.reload.sent_at

      travel 1.day { invoice.mark_sent! }

      expect(invoice.reload.sent_at).to eq(first_sent_at)
    end

    it "still names a seller who has since left the marketplace" do
      seller = create(:seller, store: store, legal_name: 'Acme GmbH')
      order.update_columns(seller_id: seller.id)
      seller_invoice = create(:invoice, order: order.reload)
      seller.destroy

      expect(seller_invoice.reload.issuer_name).to eq('Acme GmbH')
      expect(seller_invoice.update(metadata: { 'k' => 'v' })).to be(true)
    end
  end

  describe 'deletion' do
    it 'allows deleting an unsent upload' do
      invoice = create(:invoice, order: order)

      expect(invoice.destroy).to be_truthy
    end

    it "reopens the buyer's request the deleted upload had fulfilled" do
      invoice = create(:invoice, order: order)
      request = create(:invoice_request, order: order, status: 'fulfilled', invoice: invoice)

      invoice.destroy

      expect(request.reload).to have_attributes(status: 'open', invoice_id: nil)
    end

    it 'hands the request to another invoice on the order rather than reopening it' do
      first = create(:invoice, order: order)
      second = create(:invoice, order: order)
      request = create(:invoice_request, order: order, status: 'fulfilled', invoice: first)

      first.destroy

      expect(request.reload).to have_attributes(status: 'fulfilled', invoice: second)
    end

    it 'refuses deleting a sent invoice' do
      invoice = create(:invoice, :sent, order: order)

      expect(invoice.destroy).to be(false)
      expect(invoice.errors.details[:base]).to include(error: :invoice_cannot_be_deleted)
    end

    it 'refuses deleting a generated invoice' do
      invoice = create(:invoice, order: order, source: 'generated')

      expect(invoice.can_be_deleted?).to be(false)
    end

    it 'keeps an order holding an invoice from being destroyed' do
      create(:invoice, order: order)

      expect(order.destroy).to be(false)
    end
  end

  describe '#recipient_email' do
    it "is the order's email" do
      expect(build(:invoice, order: order).recipient_email).to eq(order.email)
    end

    it "is the seller's billing email for a commission invoice" do
      seller = create(:seller, store: store, billing_email: 'billing@seller.test')
      payout = create(:seller_payout, seller: seller, store: store)

      expect(build(:invoice, :commission, seller_payout: payout).recipient_email).to eq('billing@seller.test')
    end
  end

  describe 'Spree::Order.missing_invoice' do
    let!(:paid_order) { create(:completed_order_with_totals, store: store).tap { |o| o.update_columns(payment_status: 'paid', status: 'placed') } }

    it 'lists a placed, paid order with no invoice or receipt' do
      expect(Spree::Order.missing_invoice).to include(paid_order)
    end

    it 'leaves out an order with an invoice or receipt' do
      create(:invoice, :receipt, order: paid_order)

      expect(Spree::Order.missing_invoice).not_to include(paid_order)
    end

    it 'still lists an order whose only document is a credit note' do
      invoice = create(:invoice, order: paid_order)
      create(:invoice, :credit_note, order: paid_order, original_invoice: invoice)
      invoice.delete

      expect(Spree::Order.missing_invoice).to include(paid_order)
    end

    it 'lists the invoiced orders on the other side of the filter' do
      invoiced = create(:completed_order_with_totals, store: store)
      create(:invoice, order: invoiced)

      expect(Spree::Order.missing_invoice(false)).to contain_exactly(invoiced)
      expect(Spree::Order.ransack(missing_invoice: 'false').result).to contain_exactly(invoiced)
    end

    it 'ignores unpaid orders' do
      paid_order.update_columns(payment_status: 'authorized')

      expect(Spree::Order.missing_invoice).not_to include(paid_order)
    end

    it 'is not confused by commission invoices, which have no order' do
      create(:invoice, :commission, seller_payout: create(:seller_payout, store: store))

      expect(Spree::Order.missing_invoice).to include(paid_order)
    end
  end
end
