require 'spec_helper'

describe Spree::Reimbursement, type: :model do
  describe '#perform!' do
    subject { reimbursement.perform! }

    let!(:adjustments)            { [] } # placeholder to ensure it gets run prior the "before" at this level

    let!(:tax_rate)               { nil }
    let!(:tax_zone) { create(:zone_with_country, default_tax: true) }

    let(:order)                   { create(:order_with_line_items, state: 'payment', line_items_count: 1, line_items_price: line_items_price, shipment_cost: 0) }
    let(:line_items_price)        { BigDecimal(10) }
    let(:line_item)               { order.line_items.first }
    let(:inventory_unit)          { line_item.inventory_units.first }
    let(:payment)                 { build(:payment, amount: payment_amount, order: order, state: 'completed') }
    let(:payment_amount)          { order.total }
    let(:customer_return)         { build(:customer_return, return_items: [return_item]) }
    let(:return_item)             { build(:return_item, inventory_unit: inventory_unit) }

    let!(:default_refund_reason) { Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON, mutable: false) }

    let(:reimbursement) { create(:reimbursement, customer_return: customer_return, order: order, return_items: [return_item]) }

    let(:store_credit_reimbursement_type) { create(:reimbursement_type, name: 'StoreCredit', type: 'Spree::ReimbursementType::StoreCredit') }

    before do
      order.shipments.each do |shipment|
        shipment.inventory_units.update_all state: 'shipped'
        shipment.update_column('state', 'shipped')
      end
      order.reload
      order.update_with_updater!
      if payment
        payment.save!
        order.next! # confirm
      end
      order.next! # completed
      customer_return.save!
      return_item.accept!
    end

    it 'triggers the reimbursement mailer to be sent' do
      expect(Spree::ReimbursementMailer).to receive(:reimbursement_email).with(reimbursement.id) { double(deliver_later: true) }
      subject
    end
  end
end
