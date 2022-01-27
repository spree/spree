require 'spec_helper'

describe Spree::Api::Webhooks::OrderDecorator do
  let(:store) { create(:store, default: true) }
  let(:webhook_payload_body) do
    Spree::Api::V2::Platform::OrderSerializer.new(
      order,
      include: Spree::Api::V2::Platform::OrderSerializer.relationships_to_serialize.keys
      ).serializable_hash
  end

  describe 'order.canceled' do
    describe 'completed -> canceled' do
      let(:event_name) { 'order.canceled' }
      let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }
      let(:order) { create(:completed_order_with_totals, store: store) }

      it { expect { Timecop.freeze { order.cancel } }.to emit_webhook_event(event_name) }
    end
  end

  describe 'order.placed' do
    describe 'checkout -> completed' do
      let(:event_name) { 'order.placed' }
      let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }
      let(:order) { create(:order, email: 'test@example.com', store: store) }

      it { expect { order.finalize! }.to emit_webhook_event(event_name) }
    end
  end

  describe 'order.resumed' do
    let(:event_name) { 'order.resumed' }
    let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }
    let(:order) { create(:order, store: store, state: :canceled) }

    context 'when order state changes' do
      context 'when order state changes "resumed"' do
        context 'when manually setting the state' do
          # this case does not create a state change record
          subject { Timecop.freeze { order.update(state: 'resumed') } }

          it { expect { subject }.to emit_webhook_event(event_name) }
        end

        context 'when doing it through resume!' do
          subject { order.resume! }

          it { expect { subject }.to emit_webhook_event(event_name) }

          context 'after emitting the webhook' do
            it 'correctly sets state_machine_resumed used to avoid emitting the same event twice' do
              # it does so because an update is for setting the state
              # and another one is for setting the order state_changes
              order.state_machine_resumed = true
              expect(order.state_machine_resumed).to eq(true)
              subject
              expect(order.state_machine_resumed).to eq(false)
            end
          end
        end
      end

      context 'when order state does not change to "resumed"' do
        it do
          expect do
            order.update(email: 'me@spreecommerce.org')
          end.not_to emit_webhook_event(event_name)
        end
      end
    end
  end
end
