require 'spec_helper'

RSpec.describe Spree::Checkout::Advance do
  let(:service) { described_class.new }
  let(:order) { create(:order_ready_to_ship, state: :address) }
  let(:shipping_method) { create(:shipping_method) }

  describe '#call' do
    context 'with no specific target state' do
      before do
        order.update!(total: 29.99, payment_total: 0, shipment_total: 10.00, item_total: 19.99, completed_at: nil)
        order.payments.first.update!(amount: 29.99)
        order.reload

        Spree::StockItem.where(variant: order.variants).update_all(count_on_hand: 10, backorderable: false)
      end

      it 'advances the order until it cannot proceed further' do
        ensure_states_updated_only_once

        result = service.call(order: order)

        expect(result).to be_success
        expect(order.reload.state).to eq('confirm')
      end

      it 'updates order states after advancement' do
        ensure_states_updated_only_once

        service.call(order: order)

        expect(order.shipment_state).to eq('pending')
        expect(order.payment_state).to eq('paid')
      end

      context 'when no transition has been made' do
        before do
          order.payments.destroy_all
          order.update_column(:state, 'payment')
        end

        it 'responds with an error' do
          result = service.call(order: order)

          expect(result).to be_failure
          expect(result.error.value.full_messages).to contain_exactly(Spree.t(:no_payment_found))
        end
      end
    end

    context 'with specific target state' do
      it 'returns failure for invalid state' do
        result = service.call(order: order, state: 'invalid_state')

        expect(result).to be_failure
      end

      it 'returns success if order already passed target state' do
        order.update_column(:state, 'payment')

        result = service.call(order: order, state: 'address')

        expect(result).to be_success
        expect(order.state).to eq('payment')
      end

      it 'advances the order to target state' do
        ensure_states_updated_only_once

        result = service.call(order: order, state: 'delivery')

        expect(result).to be_success
        expect(order.state).to eq('delivery')
      end

      context 'when unable to reach the targeted state' do
        before do
          order.payments.destroy_all
        end

        it 'responds with an error' do
          result = service.call(order: order, state: 'complete')

          expect(result).to be_failure
          expect(result.error.value.full_messages).to contain_exactly(Spree.t(:no_payment_found))
        end
      end
    end

    context 'with shipping method selection' do
      let(:new_shipping_method) { create(:shipping_method) }
      let(:order) { create(:order_ready_to_ship, state: :address) }

      it 'updates shipping method during advancement' do
        expect_next_instance_of(Spree::Checkout::SelectShippingMethod) do |instance|
          expect(instance).
            to receive(:call).
            with(order: order, params: { shipping_method_id: new_shipping_method.id }).
            and_call_original
        end
        ensure_states_updated_only_once

        result = service.call(order: order, shipping_method_id: new_shipping_method.id, state: 'delivery')

        expect(result).to be_success
        expect(order.shipping_method).to eq(new_shipping_method)
        expect(order.reload.state).to eq('delivery')
      end

      context 'on shipping method failure' do
        before do
          allow_next_instance_of(Spree::Checkout::SelectShippingMethod) do |instance|
            allow(instance).to receive(:call).
              and_return(
                double(
                  :failure,
                  success?: false, failure?: true,
                  value: order, error: 'Shipping method error'
                )
              )
          end
        end

        it 'keeps the old shipping method' do
          result = service.call(order: order, shipping_method_id: new_shipping_method.id, state: 'delivery')

          expect(result).to be_success
          expect(order.reload.shipping_method).to eq(order.shipments.first.shipping_method)
          expect(order.state).to eq('delivery')
        end
      end
    end

    context 'when next service fails' do
      before do
        allow_next_instance_of(Spree::Dependencies.checkout_next_service.constantize) do |instance|
          allow(instance).to receive(:call).and_return(Spree::ServiceModule::Result.new(false, order))
        end
      end

      it 'returns failure result' do
        old_order_state = order.state
        result = service.call(order: order)

        expect(result).to be_failure
        expect(order.reload.state).to eq(old_order_state)
      end
    end

    context 'when order is complete' do
      let(:order) { create(:order_ready_to_ship) }

      it 'stops advancement' do
        expect(Spree::Dependencies.checkout_next_service.constantize).not_to receive(:new)

        result = service.call(order: order)

        expect(result).to be_success
        expect(order.state).to eq('complete')
      end
    end
  end

  def ensure_states_updated_only_once
    updater_spy = order.updater
    allow(order).to receive(:updater).and_return(updater_spy)
    expect(updater_spy).to receive(:update_shipment_state).once.and_call_original
    expect(updater_spy).to receive(:update_payment_state).once.and_call_original
  end
end
