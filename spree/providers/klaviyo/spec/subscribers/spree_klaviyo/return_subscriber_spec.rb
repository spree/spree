require 'spec_helper'

RSpec.describe SpreeKlaviyo::ReturnSubscriber do
  let(:store) { @default_store }
  let(:return_record) { create(:received_return, store: store) }
  let(:event) { spree_event('return.refunded', { id: return_record.prefixed_id }) }

  def handle
    described_class.new.call(event)
  end

  context 'with an active Klaviyo integration' do
    let!(:integration) { create(:klaviyo_integration, :active, store: store) }

    it "sends Return Refunded with the event's id and time" do
      create(:store_credit, originator: return_record, amount: 10)

      expect { handle }.to have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(
        integration, return_record, 'return_refunded', event_id: event.id, published_at: event.created_at
      )
    end

    it 'sends nothing when nothing was refunded' do
      expect { handle }.not_to enqueue_a_klaviyo_job
    end
  end

  it 'enqueues nothing without an active Klaviyo integration' do
    create(:store_credit, originator: return_record, amount: 10)
    create(:klaviyo_integration, store: store, active: false)

    expect { handle }.not_to enqueue_a_klaviyo_job
  end
end
