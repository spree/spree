require 'spec_helper'

RSpec.describe SpreeKlaviyo::OrderSubscriber do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store, line_items_count: 2) }

  def handle(name, record, metadata: {})
    described_class.new.call(spree_event(name, { id: record.prefixed_id }, metadata: metadata))
  end

  context 'with an active Klaviyo integration' do
    let!(:integration) { create(:klaviyo_integration, :active, store: store) }

    describe 'order.placed' do
      it 'imports the profile, sends Placed Order and one Ordered Product per line' do
        expect { handle('order.placed', order) }.
          to have_enqueued_job(SpreeKlaviyo::SyncProfileJob).with(integration, order).
          and have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, order, 'placed_order', notify_customer: true).
          and have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, order.line_items.first, 'ordered_product').
          and have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, order.line_items.second, 'ordered_product')
      end

      it "passes on the staff's choice not to notify the customer" do
        expect { handle('order.placed', order, metadata: { notify_customer: false }) }.
          to have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, order, 'placed_order', notify_customer: false)
      end

      it 'sends nothing for a child order of a split checkout' do
        group = create(:order_group, :with_parcels, store: store)

        expect { handle('order.placed', group.orders.first) }.not_to enqueue_a_klaviyo_job
      end
    end

    describe 'order_group.completed' do
      let(:cart) { create(:cart, store: store) }
      let(:group) { create(:order_group, :with_parcels, store: store, cart: cart) }

      it "imports the profile from the cart and sends the group's Placed Order and every line" do
        expect { handle('order_group.completed', group) }.
          to have_enqueued_job(SpreeKlaviyo::SyncProfileJob).with(integration, cart).
          and have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, group, 'placed_order', notify_customer: true).
          and have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, group.line_items.first, 'ordered_product').
          and have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, group.line_items.second, 'ordered_product')
      end
    end

    describe 'order.canceled' do
      it 'sends Canceled Order' do
        expect { handle('order.canceled', order, metadata: { notify_customer: false }) }.
          to have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, order, 'canceled_order', notify_customer: false)
      end
    end
  end

  it 'enqueues nothing without an active Klaviyo integration' do
    create(:klaviyo_integration, store: store, active: false)

    expect { handle('order.placed', order) }.not_to enqueue_a_klaviyo_job
    expect { handle('order.canceled', order) }.not_to enqueue_a_klaviyo_job
  end
end
