require 'spec_helper'

module Spree
  describe OrderUpdater, type: :model do
    let(:order) { create(:order) }
    let(:updater) { order.updater }

    context 'order totals' do
      before do
        create_list(:line_item, 2, order: order, price: 10)
        order.reload
        order.recalculate_totals!
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
          Promotion::Actions::CreateAdjustment.create!(calculator: calculator,
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

    describe '#recalculate_totals!' do
      it 'updates item count' do
        create(:line_item, order: order)
        create(:line_item, order: order)

        order.recalculate_totals!

        expect(order.item_count).to eq(2)
      end
    end

    # The status shims delegate to Spree::Orders::UpdateStatuses, the sole
    # writer of fulfillment_status — so these run against real fulfillments.
    context 'updating shipment state' do
      # Fulfillment#determine_state re-derives each state from the order, so
      # these need a placed order for the factory statuses to survive.
      let(:order) { create(:completed_order_with_totals, line_items_count: 1) }

      before { order.fulfillments.destroy_all }

      it 'is backordered' do
        create(:fulfillment, order: order, status: 'pending')
        allow(order).to receive(:backordered?).and_return(true)

        updater.update_shipment_state

        expect(order.fulfillment_status).to eq('backorder')
      end

      it 'is nil' do
        updater.update_shipment_state

        expect(order.fulfillment_status).to be_nil
      end

      ['fulfilled', 'pending'].each do |status|
        it "is #{status}" do
          create(:fulfillment, order: order, status: status)

          updater.update_shipment_state

          expect(order.fulfillment_status).to eq(status)
        end
      end

      # Fulfillment#determine_state only yields 'ready' once the order is paid.
      context 'when the order is paid' do
        before { allow(order).to receive(:paid?).and_return(true) }

        it 'is ready' do
          create(:fulfillment, order: order, status: 'ready')

          updater.update_shipment_state

          expect(order.fulfillment_status).to eq('ready')
        end

        it 'rolls ready_for_pickup up as ready' do
          create(:fulfillment, order: order, status: 'ready_for_pickup')

          updater.update_shipment_state

          expect(order.fulfillment_status).to eq('ready')
        end
      end

      it 'is partial' do
        create(:fulfillment, order: order, status: 'pending')
        create(:fulfillment, order: order, status: 'fulfilled')

        updater.update_shipment_state

        expect(order.fulfillment_status).to eq('partial')
      end
    end

    # The status shims delegate to Spree::Orders::UpdateStatuses, the sole
    # writer of payment_status — so these run against real payments and use
    # its vocabulary (none/authorized/partially_paid/paid/refunded/voided),
    # not the legacy balance_due/credit_owed/void names.
    context 'updating payment state' do
      let(:order) { create(:order_with_line_items, line_items_count: 1) }
      let(:order_total) { order.total }

      it 'is none when there are no payments' do
        updater.update_payment_state

        expect(order.payment_state).to eq('none')
      end

      it 'is authorized when a payment is only pending' do
        create(:payment, order: order, amount: order_total, state: 'pending')

        updater.update_payment_state

        expect(order.payment_state).to eq('authorized')
      end

      context 'order total is greater than payment total' do
        it 'is partially_paid' do
          create(:payment, order: order, amount: order_total - 1, state: 'completed')

          updater.update_payment_state

          expect(order.payment_state).to eq('partially_paid')
        end
      end

      context 'order total equals payment total' do
        it 'is paid' do
          create(:payment, order: order, amount: order_total, state: 'completed')

          updater.update_payment_state

          expect(order.payment_state).to eq('paid')
        end
      end

      context 'order is canceled' do
        before { order.update_columns(status: 'canceled') }

        context 'and is still unpaid' do
          it 'is none' do
            updater.update_payment_state

            expect(order.payment_state).to eq('none')
          end
        end

        context 'and payment is refunded' do
          it 'is voided' do
            payment = create(:payment, order: order, amount: order_total, state: 'completed')
            create(:refund, payment: payment, amount: order_total)

            updater.update_payment_state

            expect(order.payment_state).to eq('voided')
          end
        end
      end
    end

    shared_context 'with original shipping method gone backend only' do
      before do
        order.fulfillments.first.delivery_method.update(display_on: :back_end)
        create(:shipping_method) # create frontend available shipping method
      end
    end

    context 'completed order' do
      before { order.update(completed_at: Time.current) }

      describe '#update' do
        it 'delegates to the RecalculateTotals workflow with a deprecation warning' do
          expect(Spree::Deprecation).to receive(:warn).with(/updater#update is deprecated/i)
          expect(Spree::Carts::RecalculateTotals).to receive(:call).with(cart: order).and_call_original
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
          updater.update_shipments
        end

        it 'refreshes shipment rates' do
          allow(order).to receive_messages fulfillments: shipments

          expect(shipment).to receive(:refresh_rates)
          updater.update_shipments
        end

        it 'updates the shipment amount' do
          allow(order).to receive_messages fulfillments: shipments

          expect(shipment).to receive(:update_amounts)
          updater.update_shipments
        end

        context 'refresh rates' do
          include_context 'with original shipping method gone backend only'
          let(:order) { create(:completed_order_with_totals) }

          it 'keeps the original delivery method' do
            expect { updater.update_shipments }.not_to change { order.fulfillments.first.delivery_method }
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
        let(:order) { create(:cart_ready_for_delivery, store: @default_store) }

        it 'resets shipping method to frontend-available' do
          Spree::OrderUpdater.new(order).update_shipments
          expect(order.fulfillments.first.delivery_method).to eq Spree::ShippingMethod.find_by(display_on: 'both')
        end
      end
    end
  end
end
