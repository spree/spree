require 'spec_helper'

module Spree
  describe Orders::Cancel do
    subject { described_class }

    let(:order) { create(:completed_order_with_totals) }
    let!(:user) { create(:admin_user) }

    let(:result) { subject.call(order: order, canceler: user) }

    # Cancelling the order cancels its fulfillments through the fulfillment
    # workflow rather than reimplementing the restock, so extension hooks and
    # guards registered there apply to an order cancellation too.
    describe 'fulfillments' do
      let(:order) { create(:order_ready_to_ship, line_items_count: 1) }

      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'cancels each fulfillment through Fulfillments::Cancel' do
        seen = []
        Spree.hooks.register('fulfillments.cancel.after_cancel') { |flow| seen << flow.fulfillment }

        subject.call(order: order, canceler: user)

        expect(seen).to eq(order.fulfillments.to_a)
        expect(order.fulfillments.reload).to all(be_canceled)
      end

      # The goods never left the shelf — placement only promised them — so
      # cancelling withdraws the promise and leaves the physical count alone.
      it 'withdraws the promise made at placement' do
        fulfillment = order.fulfillments.first
        variant = fulfillment.fulfillment_items.first.variant
        quantity = fulfillment.fulfillment_items.where(variant_id: variant.id).sum(:quantity)
        stock_level = fulfillment.stock_location.stock_level(variant)
        fulfillment.stock_location.allocate(variant, quantity, fulfillment)

        count_on_hand_before = stock_level.reload.count_on_hand

        expect { subject.call(order: order, canceler: user) }.
          to change { stock_level.reload.allocated_count }.by(-quantity)

        expect(stock_level.reload.count_on_hand).to eq(count_on_hand_before)
      end

      # The carrier calls are batched after the order transaction commits, so
      # they must still happen — just not from inside the fulfillment workflow.
      it 'tells each provider to stand down' do
        expect_any_instance_of(Spree::FulfillmentProvider::Manual).
          to receive(:cancel_fulfillment).at_least(:once)

        subject.call(order: order, canceler: user)
      end
    end

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

    # A split checkout is the one flow where the refund amount is read: the
    # payment is shared, so what comes back is this order's own share.
    describe 'refunding a share of a shared payment' do
      let(:order) { create(:completed_order_with_totals, order_group: create(:order_group)) }
      let!(:split) do
        create(:payment_split, order: order, currency: order.currency,
                               authorized_amount: BigDecimal(30), captured_amount: BigDecimal(30))
      end

      # The amount arrives from JSON as a string, and money comparison further
      # down raises on one — so the workflow has to coerce before comparing.
      it 'accepts the amount as a string, as the API delivers it' do
        expect(Spree.refund_create_workflow).to receive(:call).
          with(hash_including(amount: BigDecimal('25'))).
          and_return(Spree::ServiceModule::Result.new(true, nil, nil))

        result = subject.call(order: order, canceler: user, refund_payments: true, refund_amount: '25.00')

        expect(result).to be_success
      end
    end

    # Every completed payment is settled through the gateway's own cancel verb,
    # whatever `refund_payments` says: a plain gateway voids it, and Stripe —
    # which cannot void a drawn charge — refunds. The flag governs the shared
    # payment of a split checkout, which is settled by hand below.
    describe 'settling a completed payment' do
      let(:order) { create(:completed_order_with_totals) }
      let!(:payment) { create(:payment, order: order, amount: order.total, status: 'completed') }

      it 'hands it to the gateway to settle' do
        expect_any_instance_of(Spree::Payment).to receive(:cancel!)

        subject.call(order: order, canceler: user)
      end

      it 'voids it on a gateway that can, leaving nothing half-settled' do
        subject.call(order: order, canceler: user)

        expect(payment.reload).to be_void
      end
    end

    describe 'a capped refund on an ordinary order' do
      it 'is refused rather than silently refunding everything' do
        result = subject.call(order: order, canceler: user, refund_payments: true, refund_amount: '25.00')

        expect(result).to be_failure
        expect(order.errors[:base].join).to include('shared')
        expect(order.reload).not_to be_canceled
      end
    end

    describe 'reason and note' do
      it 'records the canceler and leaves the reason unset when none is given' do
        result

        order.reload
        expect(order.cancel_reason).to be_nil
        expect(order.cancel_note).to be_nil
        expect(order.canceler).to eq(user)
      end

      context 'with a reason and note' do
        let(:reason) { create(:order_cancellation_reason, store: order.store) }
        let(:result) do
          subject.call(order: order, canceler: user, reason: reason, note: 'Supplier let us down')
        end

        it 'records them on the order' do
          result

          order.reload
          expect(order.cancel_reason).to eq(reason)
          expect(order.cancel_note).to eq('Supplier let us down')
        end
      end

      context 'with a reason belonging to another store' do
        let(:reason) { create(:order_cancellation_reason, store: create(:store)) }
        let(:result) do
          subject.call(order: order, canceler: user, reason: reason)
        end

        it 'refuses before anything is written' do
          expect(result).to be_failure
          expect(order.errors[:cancel_reason]).to be_present
          expect(order.reload.canceled_at).to be_nil
          expect(order.cancel_reason).to be_nil
        end
      end
    end
  end
end
