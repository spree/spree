require 'spec_helper'

module Spree
  describe Fulfillments::Fulfill do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store, line_items_count: 2) }
    let(:fulfillment) { order.fulfillments.first }
    let(:line_items) { order.line_items.sort_by(&:id) }

    describe 'fulfilling everything (items omitted)' do
      let(:execute) { subject.call(fulfillment: fulfillment) }

      it 'fulfills the fulfillment in place without splitting' do
        expect(execute.success?).to eq(true)
        expect(execute.value).to eq(fulfillment)
        expect(fulfillment.reload).to be_fulfilled
        expect(order.reload.fulfillments.count).to eq(1)
      end

      it 'rolls the order up to fulfilled' do
        execute
        expect(order.reload.fulfillment_status).to eq('fulfilled')
      end
    end

    describe 'fulfilling a subset' do
      # Two units of each line item, so shipping one unit leaves a remainder
      # both within that line item and across the order.
      let(:partial_order) do
        create(:order_ready_to_ship, store: store, line_items_count: 2).tap do |order|
          order.line_items.each { |line_item| line_item.update_columns(quantity: 2) }
          order.fulfillments.first.fulfillment_items.update_all(quantity: 2)
          order.reload
        end
      end
      let(:source) { partial_order.fulfillments.first }
      let(:first_item) { partial_order.line_items.sort_by(&:id).first }

      let(:execute) do
        subject.call(fulfillment: source, items: [{ line_item: first_item, quantity: 1 }])
      end

      it 'splits the requested units into a new fulfillment and ships that one' do
        shipped = execute.value

        expect(execute.success?).to eq(true)
        expect(shipped).not_to eq(source)
        expect(shipped).to be_fulfilled
        expect(shipped.fulfillment_items.sum(:quantity)).to eq(1)
      end

      it 'leaves the remainder open on the source fulfillment' do
        execute

        expect(source.reload).not_to be_fulfilled
        # 2 of the first line item + 2 of the second, minus the 1 shipped.
        expect(source.fulfillment_items.sum(:quantity)).to eq(3)
      end

      it 'reports the order as partially fulfilled' do
        execute
        expect(partial_order.reload.fulfillment_status).to eq('partial')
      end

      it 'does not split when the requested items cover everything held' do
        items = partial_order.line_items.map { |line_item| { line_item: line_item, quantity: 2 } }

        result = subject.call(fulfillment: source, items: items)

        expect(result.value).to eq(source)
        expect(partial_order.reload.fulfillments.count).to eq(1)
        expect(source.reload).to be_fulfilled
      end

      it 'treats zero quantities as no selection and fulfills everything' do
        result = subject.call(fulfillment: source, items: [{ line_item: first_item, quantity: 0 }])

        expect(result.value).to eq(source)
        expect(source.reload).to be_fulfilled
      end
    end

    describe 'guards' do
      it 'refuses a quantity the fulfillment does not hold' do
        result = subject.call(
          fulfillment: fulfillment,
          items: [{ line_item: line_items.first, quantity: 99 }]
        )

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to match(/exceeds the .* held by this fulfillment/)
        expect(fulfillment.reload).not_to be_fulfilled
      end

      # Shipping a canceled fulfillment is deliberate — the goods went out
      # anyway — so the workflow must not second-guess it.
      it 'fulfills a canceled fulfillment' do
        fulfillment.update!(status: 'canceled')

        result = subject.call(fulfillment: fulfillment)

        expect(result.success?).to eq(true)
        expect(fulfillment.reload).to be_fulfilled
      end

      # force exists for unpaid invoices; a draft has not been agreed at all,
      # so not even force hands its goods over.
      it 'refuses a draft order, even with force' do
        order.update_columns(status: 'draft', completed_at: nil)

        result = subject.call(fulfillment: fulfillment, force: true)

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.order_draft'))
        expect(fulfillment.reload).not_to be_fulfilled
      end

      it 'refuses a fulfillment already fulfilled' do
        fulfillment.update!(status: 'fulfilled')

        result = subject.call(fulfillment: fulfillment)

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.cannot_fulfill'))
      end

      # Deliberately NOT rolled back: the label step sits between the split
      # and the fulfilled write, so by the time fulfilling fails a label may
      # already be bought for the split parcel — rolling the parcel away
      # would orphan a paid label. The split survives, unfulfilled, and a
      # retry picks it up.
      it 'keeps the split parcel unfulfilled when fulfilling it fails' do
        allow_any_instance_of(Spree::Fulfillment).to receive(:publish_fulfillment_fulfilled_event).
          and_raise(RuntimeError, 'carrier exploded')

        expect {
          begin
            subject.call(fulfillment: fulfillment, items: [{ line_item: line_items.first, quantity: 1 }])
          rescue RuntimeError
            nil
          end
        }.to change { order.reload.fulfillments.count }.by(1)

        expect(order.fulfillments.reload.map(&:status)).to all(eq('unfulfilled'))
      end
    end

    # A canceled fulfillment already restocked its units, so shipping it
    # directly has to take them off the shelf again. This used to ride on the
    # resume transition callback.
    describe 'fulfilling a canceled fulfillment' do
      before { fulfillment.update!(status: 'canceled') }

      it 'takes the units back off the shelf' do
        variant = fulfillment.fulfillment_items.first.variant
        stock_level = fulfillment.stock_location.stock_level(variant)

        expect { subject.call(fulfillment: fulfillment) }.
          to change { stock_level.reload.count_on_hand }.by(
            -fulfillment.fulfillment_items.where(variant_id: variant.id).sum(:quantity)
          )
        expect(fulfillment.reload).to be_fulfilled
      end

      it 'does not unstock when the fulfillment was open' do
        Spree.fulfillment_resume_workflow.call(fulfillment: fulfillment)
        variant = fulfillment.fulfillment_items.first.variant
        stock_level = fulfillment.stock_location.stock_level(variant)

        expect { subject.call(fulfillment: fulfillment) }.
          not_to change { stock_level.reload.count_on_hand }
      end
    end

    describe 'stock' do
      let(:variant) { fulfillment.fulfillment_items.first.variant }
      let(:quantity) { fulfillment.fulfillment_items.where(variant_id: variant.id).sum(:quantity) }
      let(:stock_level) { fulfillment.stock_location.stock_level(variant) }

      it 'ships only the units the fulfillment holds a promise for' do
        fulfillment.stock_location.allocate(variant, quantity, fulfillment)

        expect { subject.call(fulfillment: fulfillment) }.
          to change { stock_level.reload.count_on_hand }.by(-quantity).
          and change { stock_level.reload.allocated_count }.by(-quantity)
      end

      # A fulfillment created before typed movements holds no allocation — its
      # stock left the shelf at placement under the old model — so shipping it
      # must not decrement a second time.
      it 'writes nothing for an unallocated fulfillment' do
        expect { subject.call(fulfillment: fulfillment) }.
          not_to change { stock_level.reload.count_on_hand }
      end

      # Departure is a physical fact: a forced dispatch records the parcel even
      # when the shelf says the goods were never there. Availability is
      # untouched on the way through — the promise had already been subtracted.
      it 'leaves the shelf negative on a forced dispatch from an empty shelf' do
        stock_level.update_column(:count_on_hand, 0)
        fulfillment.stock_location.allocate(variant, quantity, fulfillment)
        available_before = stock_level.reload.available_count

        result = subject.call(fulfillment: fulfillment, force: true)

        expect(result.success?).to eq(true)
        expect(stock_level.reload.count_on_hand).to eq(-quantity)
        expect(stock_level.allocated_count).to eq(0)
        expect(stock_level.available_count).to eq(available_before)
      end
    end

    describe 'tracking' do
      it 'stores the tracking number on the fulfillment that ships' do
        subject.call(fulfillment: fulfillment, tracking: '1Z999')

        expect(fulfillment.reload.tracking).to eq('1Z999')
      end

      it 'puts tracking on the split fulfillment, not the remainder' do
        partial = create(:order_ready_to_ship, store: store, line_items_count: 1).tap do |order|
          order.line_items.each { |line_item| line_item.update_columns(quantity: 2) }
          order.fulfillments.first.fulfillment_items.update_all(quantity: 2)
          order.reload
        end
        source = partial.fulfillments.first
        source_tracking = source.tracking

        shipped = subject.call(
          fulfillment: source,
          items: [{ line_item: partial.line_items.first, quantity: 1 }],
          tracking: '1Z999'
        ).value

        expect(shipped).not_to eq(source)
        expect(shipped.tracking).to eq('1Z999')
        expect(source.reload.tracking).to eq(source_tracking)
      end
    end

    # The email rides on the fulfillment.fulfilled event's metadata, so the
    # flag is asserted where it is published rather than by reaching into the
    # mailer (which lives in a different gem).
    describe 'customer notification' do
      before do
        allow(Spree::Events).to receive(:enabled?).and_return(true)
        allow(Spree::Events).to receive(:publish)
      end

      it 'asks subscribers to notify by default' do
        subject.call(fulfillment: fulfillment)

        expect(Spree::Events).to have_received(:publish).
          with('fulfillment.fulfilled', anything, hash_including(notify_customer: true))
      end

      it 'suppresses the notification when asked' do
        subject.call(fulfillment: fulfillment, notify_customer: false)

        expect(Spree::Events).to have_received(:publish).
          with('fulfillment.fulfilled', anything, hash_including(notify_customer: false))
      end

      it 'carries the flag on the legacy shipment.shipped twin too' do
        subject.call(fulfillment: fulfillment, notify_customer: false)

        expect(Spree::Events).to have_received(:publish).
          with('shipment.shipped', anything, hash_including(notify_customer: false))
      end
    end

    describe 'label-before-fulfilled ordering' do
      let(:label_provider) do
        Class.new(Spree::FulfillmentProvider::Base) do
          def create_fulfillment(_fulfillment)
            { tracking_number: 'CARRIER-XYZ' }
          end
        end.new
      end

      # The shipped email renders from the fulfilled event — it used to race
      # the label purchase for the tracking number and sometimes lose.
      it 'publishes the fulfilled event only after provider tracking is persisted' do
        fulfillment.update_column(:tracking, nil)
        allow_any_instance_of(Spree::Fulfillment).to receive(:provider).and_return(label_provider)

        tracking_at_publish = :never_published
        allow_any_instance_of(Spree::Fulfillment).to receive(:publish_fulfillment_fulfilled_event) do |record|
          tracking_at_publish = record.reload.tracking
        end

        subject.call(fulfillment: fulfillment)

        expect(tracking_at_publish).to eq('CARRIER-XYZ')
      end

      it 'still fulfills when the provider degrades to no label' do
        broken = Class.new(Spree::FulfillmentProvider::Base) do
          def create_fulfillment(_fulfillment)
            {}
          end
        end.new
        allow_any_instance_of(Spree::Fulfillment).to receive(:provider).and_return(broken)

        result = subject.call(fulfillment: fulfillment)

        expect(result).to be_success
        expect(fulfillment.reload).to be_fulfilled
      end
    end

    describe 'tracking carrier' do
      it 'stores an explicit carrier beside the number' do
        subject.call(fulfillment: fulfillment, tracking: '421432', tracking_carrier: 'inpost')

        expect(fulfillment.reload.tracking_carrier).to eq('inpost')
        expect(fulfillment.tracking_url).to include('inpost.pl')
      end

      it 'detects the carrier from a recognisable number' do
        subject.call(fulfillment: fulfillment, tracking: '1Z879E930346834440')

        expect(fulfillment.reload.tracking_carrier).to eq('ups')
      end
    end

    describe 'capturing payment on dispatch' do
      # The factory captures at checkout; undo that so the payment is merely
      # authorized, which is the state this setting exists to resolve.
      before do
        payment = order.payments.first
        payment.capture_events.delete_all
        payment.update_columns(state: 'pending')
        order.update_columns(payment_total: 0, payment_state: 'balance_due')
      end

      # The resolution chain runs per payment, so the method's own setting is
      # what decides. Clearing the legacy column lets the store's choice through.
      def set_capture_method(value)
        payment_method = order.payments.first.payment_method
        payment_method.update_columns(auto_capture: nil)
        payment_method.capture_method = value
        payment_method.save!
      end

      it 'captures the authorized payment when the method charges on dispatch' do
        set_capture_method('on_dispatch')

        subject.call(fulfillment: fulfillment)

        payment = order.payments.first.reload
        expect(payment).to be_completed
        expect(payment.captured_amount).to eq(payment.amount)
        expect(order.reload.payment_state).to eq('paid')
      end

      it 'inherits the store setting when the method sets nothing' do
        set_capture_method(nil)
        stub_store_preferences(store, capture_method: 'on_dispatch')

        subject.call(fulfillment: fulfillment)

        payment = order.payments.first.reload
        expect(payment).to be_completed
        expect(payment.captured_amount).to eq(payment.amount)
      end

      it 'leaves the payment authorized when charging is manual' do
        set_capture_method('manual')

        subject.call(fulfillment: fulfillment)

        payment = order.payments.first.reload
        expect(payment).to be_pending
        expect(payment.captured_amount).to eq(0)
      end

      # One deferred payment must not wave through a sibling that should have
      # been collected at checkout.
      it 'refuses to hand over a mixed-tender order with an uncaptured checkout payment' do
        set_capture_method('manual')
        checkout_method = create(:credit_card_payment_method, store: store, capture_method: 'checkout')
        create(:payment, order: order, payment_method: checkout_method, amount: 10, state: 'pending')

        result = subject.call(fulfillment: fulfillment)

        expect(result).to be_failure
        expect(fulfillment.reload).not_to be_fulfilled
      end

      # A 5.x row the migration leaves empty still inherits the store, so it
      # must be captured — otherwise the goods go out and the money never does.
      it 'captures a legacy auto_capture-false method when the store charges on dispatch' do
        payment_method = order.payments.first.payment_method
        payment_method.update_columns(auto_capture: false, capture_method: nil)
        stub_store_preferences(store, capture_method: 'on_dispatch')

        subject.call(fulfillment: fulfillment)

        payment = order.payments.first.reload
        expect(payment).to be_completed
        expect(payment.captured_amount).to eq(payment.amount)
      end

      # The whole point of picking manual is that staff decide when to charge;
      # a dispatch must not quietly do it for them.
      it 'does not capture a manual payment even when the store charges on dispatch' do
        set_capture_method('manual')
        stub_store_preferences(store, capture_method: 'on_dispatch')

        subject.call(fulfillment: fulfillment)

        expect(order.payments.first.reload).to be_pending
      end
    end

    describe 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'lets a validate handler veto before anything is written' do
        Spree.hooks.register('fulfillments.fulfill.validate') { |flow| flow.reject!('past the cut-off') }

        result = subject.call(fulfillment: fulfillment)

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to eq('past the cut-off')
        expect(fulfillment.reload).not_to be_fulfilled
      end

      it 'runs after_fulfill with the shipped fulfillment' do
        seen = nil
        Spree.hooks.register('fulfillments.fulfill.after_fulfill') { |flow| seen = flow.fulfillment }

        subject.call(fulfillment: fulfillment)

        expect(seen).to eq(fulfillment)
      end
    end
  end
end
