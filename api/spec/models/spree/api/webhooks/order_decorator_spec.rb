require 'spec_helper'

describe Spree::Api::Webhooks::OrderDecorator do
  let(:store) { create(:store, default: true) }
  let(:body) { Spree::Api::V2::Platform::OrderSerializer.new(order).serializable_hash.to_json }

  describe 'order.canceled' do
    describe 'completed -> canceled' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it { expect { Timecop.freeze { order.cancel } }.to emit_webhook_event('order.canceled') }
    end
  end

  describe 'order.placed' do
    describe 'checkout -> completed' do
      let(:order) { create(:order, email: 'test@example.com', store: store) }

      it { expect { Timecop.freeze { order.finalize! } }.to emit_webhook_event('order.placed') }
    end
  end

  describe 'order.resumed' do
    let(:order) { create(:order, store: store, state: :canceled) }

    context 'when order state changes' do
      context 'when order state changes "resumed"' do
        context 'when manually setting the state' do
          # this case does not create a state change record
          subject { Timecop.freeze { order.update(state: 'resumed') } }

          it { expect { subject }.to emit_webhook_event('order.resumed') }
        end

        context 'when doing it through resume!' do
          it do
            expect do
              Timecop.freeze do
                order.resume!
              end
            end.to emit_webhook_event('order.resumed')
          end

          context 'after emitting the webhook' do
            it 'correctly sets state_machine_resumed used to avoid emitting the same event twice' do
              # it does so because an update is for setting the state
              # and another one is for setting the order state_changes
              order.state_machine_resumed = true
              expect(order.state_machine_resumed).to eq(true)
              order.resume!
              expect(order.state_machine_resumed).to eq(false)
            end
          end
        end
      end

      context 'when order state does not change to "resumed"' do
        it do
          expect do
            order.update(email: 'me@spreecommerce.org')
          end.not_to emit_webhook_event('order.resumed')
        end
      end
    end
  end
end
