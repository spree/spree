require 'spec_helper'
require 'spree/testing_support/order_walkthrough'

module Spree
  describe OrderUpdater, type: :model do
    let(:order) { create(:order) }
    let(:updater) { order.updater }

    context 'order totals' do
      before do
        create_list(:line_item, 2, order: order, price: 10)
        order.reload
        order.update_with_updater!
      end

      it 'updates payment totals' do
        create(:payment_with_refund, amount: 20, order: order)
        order.updater.update_payment_total
        expect(order.payment_total).to eq(15)
      end

      it 'update item total' do
        updater.update_item_total
        expect(order.item_total).to eq(20)
      end

      it 'update shipment total' do
        create(:shipment, order: order, cost: 10)
        order.reload
        updater.update_shipment_total
        expect(order.shipment_total).to eq(10)
      end

      context 'with order promotion followed by line item addition' do
        let(:promotion) { create(:promotion, name: '10% off') }
        let(:calculator) { Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) }

        let(:promotion_action) do
          PromotionActions::CreateAdjustment.create!(calculator: calculator,
                                                       promotion: promotion)
        end

        before do
          updater.update
          promotion_action
          order.promotions << promotion
          create(:line_item, order: order, price: 10) # in addition to the two already created
          order.reload
          updater.update
        end

        it 'updates promotion total' do
          expect(order.promo_total).to eq(-3)
        end
      end

      it 'update order adjustments' do
        # Tax is provider-written; stub it out so the synthetic tax line survives.
        allow(Spree).to receive(:tax_provider).and_return(instance_double(Spree::TaxProvider::Internal, estimate: nil))

        line_item = order.line_items.first
        create(:discount, order: order, line_item: line_item, amount: -2.50, kind: 'manual')
        create(:fee, order: order, amount: 5, kind: 'handling')
        create(:tax_line, order: order, line_item: line_item, amount: 0.05, included: false)

        updater.update_adjustment_total
        expect(order.adjustment_total).to eq(2.55)
        expect(order.additional_tax_total).to eq(0.05)
        expect(order.fee_total).to eq(5)
        expect(order.promo_total).to eq(0)
      end
    end

    describe '#update_with_updater!' do
      it 'updates item count' do
        create(:line_item, order: order)
        create(:line_item, order: order)

        order.update_with_updater!

        expect(order.item_count).to eq(2)
      end
    end

    context 'updating shipment state' do
      before do
        allow(order).to receive_messages backordered?: false
        allow(order).to receive_message_chain(:fulfillments, :shipped, :count).and_return(0)
        allow(order).to receive_message_chain(:fulfillments, :ready, :count).and_return(0)
        allow(order).to receive_message_chain(:fulfillments, :pending, :count).and_return(0)
      end

      it 'is backordered' do
        allow(order).to receive_messages backordered?: true
        updater.update_fulfillment_status

        expect(order.fulfillment_status).to eq('backorder')
      end

      it 'is nil' do
        allow(order).to receive_message_chain(:fulfillments, :states).and_return([])
        allow(order).to receive_message_chain(:fulfillments, :count).and_return(0)

        updater.update_fulfillment_status
        expect(order.fulfillment_status).to be_nil
      end

      ['fulfilled', 'ready', 'pending'].each do |status|
        it "is #{status}" do
          allow(order).to receive_message_chain(:fulfillments, :states).and_return([status])
          updater.update_fulfillment_status
          expect(order.fulfillment_status).to eq(status.to_s)
        end
      end

      it 'rolls ready_for_pickup up as ready' do
        allow(order).to receive_message_chain(:fulfillments, :states).and_return(['ready_for_pickup'])
        updater.update_fulfillment_status
        expect(order.fulfillment_status).to eq('ready')
      end

      it 'is partial' do
        allow(order).to receive_message_chain(:fulfillments, :states).and_return(['pending', 'fulfilled'])
        updater.update_fulfillment_status
        expect(order.fulfillment_status).to eq('partial')
      end
    end

    context 'updating payment state' do
      let(:order) { Order.new }
      let(:updater) { order.updater }

      it 'is failed if no valid payments' do
        allow(order).to receive_message_chain(:payments, :valid, :empty?).and_return(true)

        updater.update_payment_state
        expect(order.payment_state).to eq('failed')
      end

      context 'payment total is greater than order total' do
        it 'is credit_owed' do
          order.payment_total = 2
          order.total = 1

          expect do
            updater.update_payment_state
          end.to change(order, :payment_state).to 'credit_owed'
        end
      end

      context 'order total is greater than payment total' do
        it 'is balance_due' do
          order.payment_total = 1
          order.total = 2

          expect do
            updater.update_payment_state
          end.to change(order, :payment_state).to 'balance_due'
        end
      end

      context 'order total equals payment total' do
        it 'is paid' do
          order.payment_total = 30
          order.total = 30

          expect do
            updater.update_payment_state
          end.to change(order, :payment_state).to 'paid'
        end
      end

      context 'order is canceled' do
        before do
          order.state = 'canceled'
        end

        context 'and is still unpaid' do
          it 'is void' do
            order.payment_total = 0
            order.total = 30
            expect do
              updater.update_payment_state
            end.to change(order, :payment_state).to 'void'
          end
        end

        context 'and is paid' do
          it 'is credit_owed' do
            order.payment_total = 30
            order.total = 30
            allow(order).to receive_message_chain(:payments, :valid, :empty?).and_return(false)
            allow(order).to receive_message_chain(:payments, :completed, :size).and_return(1)
            expect do
              updater.update_payment_state
            end.to change(order, :payment_state).to 'credit_owed'
          end
        end

        context 'and payment is refunded' do
          it 'is void' do
            order.payment_total = 0
            order.total = 30
            expect do
              updater.update_payment_state
            end.to change(order, :payment_state).to 'void'
          end
        end
      end
    end

    it 'state change' do
      order.shipment_state = 'shipped'
      state_changes = double
      allow(order).to receive_messages state_changes: state_changes
      expect(state_changes).to receive(:create).with(
        previous_state: nil,
        next_state: 'shipped',
        name: 'shipment',
        user_id: order.user_id
      )

      order.state_changed('shipment')
    end

    shared_context 'with original shipping method gone backend only' do
      before do
        order.shipments.first.shipping_method.update(display_on: :back_end)
        create(:shipping_method) # create frontend available shipping method
      end
    end

    context 'completed order' do
      before { order.update(completed_at: Time.current) }

      describe '#update' do
        it 'updates payment state' do
          expect(updater).to receive(:update_payment_state)
          updater.update
        end

        it 'updates fulfillment status' do
          expect(updater).to receive(:update_fulfillment_status)
          updater.update
        end

        it 'updates delivery total again after updating fulfillments' do
          expect(updater).to receive(:update_delivery_total).ordered
          expect(updater).to receive(:update_fulfillments).ordered
          expect(updater).to receive(:update_delivery_total).ordered
          updater.update
        end
      end

      describe '#update_shipments' do
        let(:shipment) { create(:shipment, order: order) }
        let(:shipments) { [shipment] }

        it 'updates each shipment' do
          allow(order).to receive_messages fulfillments: shipments
          allow(shipments).to receive_messages states: []
          allow(shipments).to receive_messages ready: []
          allow(shipments).to receive_messages pending: []
          allow(shipments).to receive_messages shipped: []

          expect(shipment).to receive(:update!).with(order)
          updater.update_fulfillments
        end

        it 'refreshes shipment rates' do
          allow(order).to receive_messages fulfillments: shipments

          expect(shipment).to receive(:refresh_rates)
          updater.update_fulfillments
        end

        it 'updates the shipment amount' do
          allow(order).to receive_messages fulfillments: shipments

          expect(shipment).to receive(:update_amounts)
          updater.update_fulfillments
        end

        context 'refresh rates' do
          include_context 'with original shipping method gone backend only'
          let(:order) { create(:completed_order_with_totals) }

          it 'keeps the original shipping method' do
            expect { updater.update_shipments }.not_to change { order.shipments.first.shipping_method }
          end
        end
      end
    end

    context 'incomplete order' do
      let(:shipment) { create(:shipment) }
      let(:shipments) { [shipment] }

      it 'doesnt update payment state' do
        expect(updater).not_to receive(:update_payment_state)
        updater.update
      end

      it 'doesnt update shipment state' do
        expect(updater).not_to receive(:update_shipment_state)
        updater.update
      end

      it 'doesnt update each shipment' do
        allow(order).to receive_messages shipments: shipments
        allow(shipments).to receive_messages states: []
        allow(shipments).to receive_messages ready: []
        allow(shipments).to receive_messages pending: []
        allow(shipments).to receive_messages shipped: []

        allow(updater).to receive(:update_totals) # Otherwise this gets called and causes a scene
        expect(updater).not_to receive(:update_shipments).with(order)
        updater.update
      end

      describe '#update_shipments' do
        include_context 'with original shipping method gone backend only'
        let(:order) { ::OrderWalkthrough.up_to(:delivery) }

        it 'resets shipping method to frontend-available' do
          order.updater.update_shipments
          expect(order.shipments.first.shipping_method).to eq Spree::ShippingMethod.find_by(display_on: 'both')
        end
      end
    end
  end
end
