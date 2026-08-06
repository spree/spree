require 'spec_helper'

module Spree
  describe Orders::Cancel do
    subject { described_class }

    let(:order) { create(:completed_order_with_totals) }
    let!(:user) { create(:admin_user) }

    let(:result) { subject.call(order: order, canceler: user) }

    shared_examples 'tries to cancel' do
      context 'completed order' do
        it { expect(result).to be_success }
        it { expect { result }.to change(order, :status).to('canceled') }
        it { expect(result.value).to eq(order) }

        it 'publishes order.canceled event', :events do
          allow(Spree::Events).to receive(:publish)
          result
          expect(Spree::Events).to have_received(:publish).with('order.canceled', hash_including(:notify_customer), any_args)
        end
      end

      context 'incomplete order' do
        let(:order) { create(:order_with_totals) }

        it { expect(result).to be_failure }
        it { expect(result.error).to be_present }

        it 'does not publish order.canceled event', :events do
          allow(Spree::Events).to receive(:publish)
          result
          expect(Spree::Events).not_to have_received(:publish).with('order.canceled', any_args)
        end
      end
    end

    context 'with canceler passed' do
      it_behaves_like 'tries to cancel'

      it { expect { result }.to change(order, :canceler).to(user) }
    end

    context 'without canceler passed' do
      let(:user) { nil }

      it_behaves_like 'tries to cancel'
    end

    describe 'tax lifecycle' do
      it 'reverses the filed tax document so the sale leaves the liability' do
        provider = instance_double(Spree::TaxProvider::Internal, void: nil, estimate: nil)
        allow(order).to receive(:tax_provider).and_return(provider)

        result

        expect(provider).to have_received(:void).with(order)
      end
    end

    describe 'OrderCancellation record creation' do
      it 'creates a cancellation record with default reason' do
        expect { result }.to change(order.cancellations, :count).by(1)
        cancellation = order.cancellations.last
        expect(cancellation.reason).to eq('other')
        expect(cancellation.canceled_by).to eq(user)
      end

      context 'with all new keyword arguments' do
        let(:result) do
          subject.call(
            order: order,
            canceler: user,
            reason: 'inventory',
            note: 'Out of stock',
            restock_items: true,
            refund_payments: true,
            refund_amount: 25.00,
            notify_customer: true
          )
        end

        it 'records all fields on the cancellation' do
          result
          cancellation = order.cancellations.last
          expect(cancellation.reason).to eq('inventory')
          expect(cancellation.note).to eq('Out of stock')
          expect(cancellation.restock_items).to be true
          expect(cancellation.refund_payments).to be true
          expect(cancellation.refund_amount).to eq(25.00)
          expect(cancellation.notify_customer).to be true
          expect(cancellation.canceled_by).to eq(user)
        end
      end

      context 'when the cancellation is invalid' do
        let(:result) do
          subject.call(order: order, canceler: user, reason: 'not_a_real_reason')
        end

        it 'returns a failure result and rolls back' do
          expect(result).to be_failure
          expect(order.reload.canceled_at).to be_nil
          expect(order.cancellations).to be_empty
        end
      end
    end
  end
end
