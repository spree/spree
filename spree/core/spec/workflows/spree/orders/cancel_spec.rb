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

      it 'withdraws what an edit after placement added to the promise' do
        fulfillment = order.fulfillments.first
        line_item = order.line_items.first
        variant = line_item.variant
        placed_quantity = line_item.quantity
        stock_level = fulfillment.stock_location.stock_level(variant)
        fulfillment.stock_location.allocate(variant, placed_quantity, fulfillment)

        Spree::Orders::Update.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: placed_quantity + 1 }] })

        expect { subject.call(order: order.reload, canceler: user) }.
          to change { stock_level.reload.allocated_count }.by(-(placed_quantity + 1))
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
          expect(Spree::Events).to have_received(:publish).with('order.canceled', kind_of(Hash), hash_including(:notify_customer))
        end
      end

      context 'an order whose goods have gone out' do
        let(:order) { create(:completed_order_with_totals) }

        before { order.update_columns(fulfillment_status: 'fulfilled') }

        it { expect(result).to be_failure }

        it 'says why it refused' do
          expect(result.error.value.full_messages.join).
            to include(I18n.t('spree.errors.messages.not_cancellable'))
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

      # The cancellation and its payments are settled before the void runs, and
      # the steps after it update statuses and announce it — so raising left a
      # cancelled order half-recorded and reported a failure.
      it 'cancels the order even when the tax engine cannot be reached' do
        provider = instance_double(Spree::TaxProvider::Internal, estimate: nil)
        allow(provider).to receive(:void).
          and_raise(Spree::Tax::ProviderUnavailable.new('Failed to open TCP connection'))
        allow(order).to receive(:tax_provider).and_return(provider)
        allow(Rails.error).to receive(:report)

        expect(result).to be_success
        expect(order.reload).to be_canceled
        # Void is idempotent, so a standing document can follow — but the gap
        # is reported rather than dropped.
        expect(Rails.error).to have_received(:report).
          with(instance_of(Spree::Tax::ProviderUnavailable), hash_including(source: 'spree.orders.cancel'))
      end
    end

    # A split checkout is the one flow where the refund amount is read: the
    # payment is shared, so what comes back is this order's own share.
    describe 'refunding a share of a shared payment' do
      let(:order) { create(:completed_order_with_totals, order_group: create(:order_group)) }
      let!(:split) do
        create(:payment_split, order: order, currency: order.currency,
                               payment: create(:payment, order: nil, cart: nil, order_group: order.order_group,
                                                         amount: 30, status: 'completed'),
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

      # A void releases the whole charge, so a partly refunded one would give
      # back again what its refunds already returned. Only the rest goes back.
      it 'refunds only the remainder of a partly refunded charge instead of voiding it' do
        create(:refund, payment: payment, amount: 10)

        subject.call(order: order, canceler: user, refund_payments: true)

        expect(payment.reload).not_to be_void
        expect(payment.refunds.sum(:amount)).to eq(payment.amount)
      end

      # Stripe and PayPal cannot void a drawn charge: they refund it or, when
      # the operator keeps the money, leave it standing. The order must then
      # still read as paid.
      context 'on a gateway that cannot void a captured charge' do
        before do
          allow_any_instance_of(Spree::Gateway::Bogus).to receive(:can_void?) { |_gateway, payment| !payment.completed? }
          allow_any_instance_of(Spree::Gateway::Bogus).to receive(:cancel).and_wrap_original do |original, response_code, payment, refund:|
            next original.call(response_code, payment, refund: refund) unless refund

            result = Spree.refund_create_workflow.call(payment: payment, reason: Spree::RefundReason.order_canceled_reason(payment.owner.store))
            raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?

            Spree::PaymentResponse.new(true, 'refunded', {}, authorization: payment.response_code)
          end
        end

        it 'keeps the payment completed and the order paid when the money is kept' do
          subject.call(order: order, canceler: user)

          expect(payment.reload).to be_completed
          expect(order.reload.payment_total).to eq(payment.amount)
        end

        it 'keeps the payment completed with the refund recorded when the money is given back' do
          subject.call(order: order, canceler: user, refund_payments: true)

          expect(payment.reload).to be_completed
          expect(payment.refunds.sum(:amount)).to eq(payment.amount)
          expect(order.reload.payment_total).to eq(0)
        end

        # Store credit writes no refund row, so the payment's own balance
        # cannot tell the order already gave its money back (V-3832).
        it 'refunds nothing when store credit already gave everything back' do
          create(:store_credit, refunded_order: order, customer: order.customer, store: order.store, amount: payment.amount)

          result = subject.call(order: order, canceler: user, refund_payments: true)

          expect(result).to be_success
          expect(order.reload).to be_canceled
          expect(payment.refunds).to be_empty
        end

        it 'refunds only what store credit left' do
          create(:store_credit, refunded_order: order, customer: order.customer, store: order.store, amount: 10)

          subject.call(order: order, canceler: user, refund_payments: true)

          expect(payment.refunds.sum(:amount)).to eq(payment.amount - 10)
        end
      end

      # Releasing a store-credit payment hands back all of it whatever the
      # caller asked, so it is held to what the order has left to give once
      # the card is settled.
      context 'with part of the order paid in store credit' do
        let!(:payment) { create(:payment, order: order, amount: order.total - 20, status: 'completed') }
        let(:credit) { create(:store_credit, store: order.store, customer: order.customer, amount: 20) }
        let!(:credit_payment) do
          create(:store_credit_payment, order: order, source: credit, amount: 20, status: 'completed').tap do |credit_payment|
            code = credit.authorize(BigDecimal(20), order.currency)
            credit.capture(BigDecimal(20), code, order.currency)
            credit_payment.update_columns(response_code: code)
          end
        end

        def credit_released
          Spree::StoreCreditEvent.where(store_credit: credit, action: Spree::StoreCredit::CREDIT_ACTION).sum(:amount)
        end

        it 'releases it all when nothing was given back yet' do
          subject.call(order: order, canceler: user)

          expect(credit_payment.reload).to be_void
          expect(credit_released).to eq(20)
        end

        it 'releases none of it once a return gave the same back as store credit' do
          create(:store_credit, refunded_order: order, customer: order.customer, store: order.store, amount: 20)

          subject.call(order: order, canceler: user)

          expect(payment.reload).to be_void
          expect(credit_payment.reload).to be_completed
          expect(credit_released).to eq(0)
        end

        context 'on a gateway that cannot void a captured charge' do
          before do
            allow_any_instance_of(Spree::Gateway::Bogus).to receive(:can_void?) { |_gateway, payment| !payment.completed? }
            allow_any_instance_of(Spree::Gateway::Bogus).to receive(:cancel).and_wrap_original do |original, response_code, payment, refund:|
              next original.call(response_code, payment, refund: refund) unless refund

              result = Spree.refund_create_workflow.call(payment: payment, reason: Spree::RefundReason.order_canceled_reason(payment.owner.store))
              raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?

              Spree::PaymentResponse.new(true, 'refunded', {}, authorization: payment.response_code)
            end
          end

          it 'refunds the card and releases no credit once a return gave the credit back' do
            create(:store_credit, refunded_order: order, customer: order.customer, store: order.store, amount: 20)

            subject.call(order: order, canceler: user, refund_payments: true)

            expect(payment.refunds.sum(:amount)).to eq(payment.amount)
            expect(credit_payment.reload).to be_completed
            expect(credit_released).to eq(0)
          end

          it 'releases only the credit the return left' do
            create(:store_credit, refunded_order: order, customer: order.customer, store: order.store, amount: 5)

            subject.call(order: order, canceler: user, refund_payments: true)

            expect(payment.refunds.sum(:amount)).to eq(payment.amount)
            expect(credit_payment.refunds.sum(:amount)).to eq(15)
            expect(credit_released).to eq(15)
          end
        end
      end
    end

    # An order paid in full by gift card is settled by voiding its payment,
    # which writes the whole payment off as given back.
    describe 'an order paid in full by gift card' do
      let!(:credit_payment) { create(:store_credit_payment, order: order, amount: order.total, status: 'completed') }

      before do
        allow(order).to receive_messages(gift_card: build_stubbed(:gift_card), covered_by_store_credit?: true)
      end

      it 'voids the payment' do
        subject.call(order: order, canceler: user)

        expect(credit_payment.reload).to be_void
      end

      it 'keeps the payment once a return gave its money back as store credit' do
        create(:store_credit, refunded_order: order, customer: order.customer, store: order.store, amount: 20)

        subject.call(order: order, canceler: user)

        expect(credit_payment.reload).to be_completed
      end
    end

    describe 'a payment waiting on its provider' do
      let(:order) { create(:completed_order_with_totals) }
      let!(:payment) { create(:payment, order: order, amount: order.total, status: 'requested') }

      it 'refuses to cancel the order' do
        result = subject.call(order: order, canceler: user)

        expect(result).to be_failure
        expect(order.errors[:base]).to include(I18n.t('spree.payment_requested_awaiting_provider'))
        expect(order.reload).not_to be_canceled
        expect(payment.reload).to be_requested
      end
    end

    describe 'a payment whose capture or void is in flight' do
      let(:order) { create(:completed_order_with_totals) }
      let!(:payment) { create(:payment, order: order, amount: order.total, status: 'processing') }

      it 'refuses to cancel the order, since the provider may yet capture it' do
        result = subject.call(order: order, canceler: user)

        expect(result).to be_failure
        expect(order.errors[:base]).to include(I18n.t('spree.payment_requested_awaiting_provider'))
        expect(order.reload).not_to be_canceled
      end
    end

    describe 'a provider that answers a cancel later' do
      let(:order) { create(:completed_order_with_totals) }

      before { payment.payment_method.update!(preferred_requested_mode: true) }

      context 'with an uncaptured payment' do
        let!(:payment) { create(:payment, order: order, amount: order.total, status: 'pending') }

        it 'leaves the payment requested, waiting on the void' do
          subject.call(order: order, canceler: user)

          expect(payment.reload).to be_requested
          expect(payment.requested_action).to eq('void')
        end
      end

      context 'with a completed payment' do
        let!(:payment) { create(:payment, order: order, amount: order.total, status: 'completed') }

        # A provider answers this only after recording the refund its outcome settles.
        it 'keeps the payment completed' do
          allow_any_instance_of(Spree::Gateway::Bogus).to receive(:cancel).and_return(Spree::PaymentResponse.new(true, 'Refund requested', {}, requested: true))

          subject.call(order: order, canceler: user)

          expect(payment.reload).to be_completed
        end
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
