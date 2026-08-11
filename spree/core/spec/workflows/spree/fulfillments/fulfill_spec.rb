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

      # The split and the fulfillment share a transaction, so a fulfillment
      # that cannot ship must not leave a stray split behind.
      it 'creates no fulfillment when the split succeeds but shipping fails' do
        allow_any_instance_of(Spree::Fulfillment).to receive(:publish_fulfillment_fulfilled_event).
          and_raise(RuntimeError, 'carrier exploded')

        expect {
          begin
            subject.call(fulfillment: fulfillment, items: [{ line_item: line_items.first, quantity: 1 }])
          rescue RuntimeError
            nil
          end
        }.not_to change { order.reload.fulfillments.count }
      end
    end

    # A canceled fulfillment already restocked its units, so shipping it
    # directly has to take them off the shelf again. This used to ride on the
    # resume transition callback.
    describe 'fulfilling a canceled fulfillment' do
      before { fulfillment.update!(status: 'canceled') }

      it 'takes the units back off the shelf' do
        variant = fulfillment.fulfillment_items.first.variant
        stock_item = fulfillment.stock_location.stock_item(variant)

        expect { subject.call(fulfillment: fulfillment) }.
          to change { stock_item.reload.count_on_hand }.by(
            -fulfillment.fulfillment_items.where(variant_id: variant.id).sum(:quantity)
          )
        expect(fulfillment.reload).to be_fulfilled
      end

      it 'does not unstock when the fulfillment was open' do
        Spree.fulfillment_resume_workflow.call(fulfillment: fulfillment)
        variant = fulfillment.fulfillment_items.first.variant
        stock_item = fulfillment.stock_location.stock_item(variant)

        expect { subject.call(fulfillment: fulfillment) }.
          not_to change { stock_item.reload.count_on_hand }
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
