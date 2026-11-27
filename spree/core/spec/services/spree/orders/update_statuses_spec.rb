require 'spec_helper'

RSpec.describe Spree::Orders::UpdateStatuses do
  let(:store) { @default_store }

  describe 'payment status' do
    let(:order) { create(:completed_order_with_totals, store: store) }

    it 'rolls up an order whose only payment waits on its provider as authorized' do
      create(:payment, order: order, amount: order.total, status: 'requested')

      described_class.call(order: order)

      expect(order.reload.payment_status).to eq('authorized')
    end

    it 'counts no refund the provider has not completed' do
      payment = create(:payment, order: order, amount: order.total, status: 'completed')
      create(:refund, :requested, payment: payment, amount: 5)
      create(:refund, :failed, payment: payment, amount: 5)

      described_class.call(order: order)

      expect(order.reload.payment_status).to eq('paid')
    end

    it 'gives the same figures for rows written by a gateway that answers at once' do
      payment = create(:payment, order: order, amount: order.total, status: 'completed')
      create(:refund, payment: payment, amount: 5)

      described_class.call(order: order)

      expect(order.reload.payment_status).to eq('partially_refunded')
    end

    it 'reads a voided payment on a placed order as none' do
      create(:payment, order: order, amount: order.total, status: 'void')

      described_class.call(order: order)

      expect(order.reload.payment_status).to eq('none')
    end

    context 'when the order is canceled' do
      before { order.update_columns(status: 'canceled', canceled_at: Time.current) }

      it 'reads captured money given back in full as refunded' do
        payment = create(:payment, order: order, amount: order.total, status: 'completed')
        create(:refund, payment: payment, amount: order.total)

        described_class.call(order: order)

        expect(order.reload.payment_status).to eq('refunded')
      end

      it 'reads captured money that was kept as paid' do
        create(:payment, order: order, amount: order.total, status: 'completed')

        described_class.call(order: order)

        expect(order.reload.payment_status).to eq('paid')
      end

      it 'reads a voided payment as voided' do
        create(:payment, order: order, amount: order.total, status: 'void')

        described_class.call(order: order)

        expect(order.reload.payment_status).to eq('voided')
      end

      it 'reads an order that never held a payment as none' do
        described_class.call(order: order)

        expect(order.reload.payment_status).to eq('none')
      end
    end
  end

  describe 'fulfillment status' do
    let(:order) { create(:order_ready_to_ship, line_items_count: 2, store: store) }

    # A recalled parcel's backordered items are no longer waited on: the order
    # is described by the parcels still going out.
    it 'ignores backordered items on a canceled fulfillment' do
      backordered = order.fulfillments.first
      live = create(:fulfillment, order: order, status: 'unfulfilled')
      order.line_items.last.fulfillment_items.update_all(fulfillment_id: live.id)
      backordered.fulfillment_items.update_all(status: 'backordered')
      backordered.update_columns(status: 'canceled')

      described_class.call(order: order)

      expect(order.reload.fulfillment_status).to eq('unfulfilled')
    end
  end

  # A split checkout's child reads its shares: a capture the provider has not
  # answered keeps its claim and leaves the share authorized.
  describe 'payment status of a split checkout child' do
    let(:group) { create(:order_group, store: store) }
    let!(:child) { create(:order, store: store, order_group: group, total: 40) }
    let(:payment) { create(:payment, order: nil, cart: nil, order_group: group, amount: 40, status: 'requested') }

    it 'rolls up a share waiting on its provider as authorized' do
      create(:payment_split, payment: payment, order: child, authorized_amount: 40, claimed_amount: 40)

      described_class.call(order: child)

      expect(child.reload.payment_status).to eq('authorized')
    end

    it 'counts nothing authorized on a share whose payment was since voided' do
      payment.update_columns(status: 'void')
      create(:payment_split, payment: payment, order: child, authorized_amount: 40)

      described_class.call(order: child)

      expect(child.reload.payment_status).to eq('none')
    end

    # Canceling writes the share down rather than voiding the shared payment,
    # and a zero share looks the same as one that never held anything.
    it 'reads a canceled child whose share was written down before capture as none' do
      create(:payment_split, payment: payment, order: child, authorized_amount: 0)
      child.update_columns(status: 'canceled', canceled_at: Time.current)

      described_class.call(order: child)

      expect(child.reload.payment_status).to eq('none')
    end
  end
end
