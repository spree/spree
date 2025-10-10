require 'spec_helper'

module Spree
  describe Cart::Destroy do
    subject { described_class.call order: order }

    context 'when order is given' do
      context 'when can be destroyed' do
        let(:order) { create(:order_with_line_items, ship_address: ship_address, bill_address: bill_address) }
        let(:shipment) { order.shipments.take }
        let!(:payment) { create(:payment, amount: order.total, order: order) }
        let!(:line_item_ids) { order.line_item_ids }
        let!(:shipment_ids) { order.shipment_ids }
        let!(:payment_ids) { order.payment_ids }

        let(:ship_address) { create(:address) }
        let(:bill_address) { create(:address) }
        let(:address_ids) { [ship_address.id, bill_address.id] }

        it 'returns success' do
          expect(subject.success?).to be true
        end

        it 'voids pending payments' do
          expect_any_instance_of(Spree::Payment).to receive(:void).exactly(order.payments.count).times

          subject
        end

        it 'cancel not shipped shipments' do
          expect_any_instance_of(Spree::Shipment).to receive(:cancel).exactly(order.shipments.count).times

          subject
        end

        it 'destroys the order' do
          expect(order.destroyed?).not_to be true

          subject

          expect(order.destroyed?).to be true
        end

        it 'destroys line_items, addresses, shipments and payments' do
          subject

          expect(Spree::LineItem.where(id: line_item_ids)).to be_empty
          expect(Spree::Shipment.where(id: shipment_ids)).to be_empty
          expect(Spree::Payment.where(id: payment_ids)).to be_empty
          expect(Spree::Address.where(id: address_ids)).to be_empty
        end

        context 'when addresses are assigned to other orders' do
          let!(:other_order) { create(:order_ready_to_ship, ship_address: ship_address, bill_address: bill_address) }

          it 'destroys the order' do
            expect(order.destroyed?).not_to be true

            subject

            expect(order.destroyed?).to be true
          end

          it 'destroys line_items, shipments and payments, but keeps addresses' do
            subject

            expect(Spree::LineItem.where(id: line_item_ids)).to be_empty
            expect(Spree::Shipment.where(id: shipment_ids)).to be_empty
            expect(Spree::Payment.where(id: payment_ids)).to be_empty

            expect(Spree::Address.where(id: address_ids)).to contain_exactly(ship_address, bill_address)
          end
        end

        context 'when empty service is called first' do
          before { Spree::Cart::Empty.call(order: order) }

          it 'destroys the order' do
            expect(order.destroyed?).not_to be true

            subject

            expect(order.destroyed?).to be true
          end
        end
      end

      context 'when cannot be destroyed' do
        let(:order) { create(:completed_order_with_totals) }

        it 'returns failure' do
          expect(subject.success?).to be false
          expect(subject.error.value).to eq Spree.t(:cannot_be_destroyed)
        end
      end
    end

    context 'when nil is given' do
      let(:order) { nil }

      before { subject }

      it 'returns failure' do
        expect(subject.success?).to be false
        expect(subject.error.value).to eq Spree.t(:cannot_be_destroyed)
      end
    end
  end
end
