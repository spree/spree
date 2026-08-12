require 'spec_helper'

RSpec.describe SpreeEasyPost::TrackerEvent do
  def webhook(status:, tracking_code: 'EZ1000000001', **extra)
    {
      'description' => 'tracker.updated',
      'result' => {
        'object' => 'Tracker',
        'tracking_code' => tracking_code,
        'status' => status,
        'carrier' => 'USPS',
        'public_url' => 'https://track.easypost.com/EZ1000000001'
      }.merge(extra)
    }
  end

  describe '.from_webhook' do
    it 'reads a carrier status into the Spree vocabulary' do
      event = described_class.from_webhook(webhook(status: 'out_for_delivery'))

      expect(event.tracking_code).to eq('EZ1000000001')
      expect(event.status).to eq('out_for_delivery')
      expect(Spree::Fulfillment::TRACKING_STATUSES).to include(event.status)
    end

    # EasyPost spells a few of its own states differently from ours; the point
    # of the map is that core never has to know that.
    it 'folds carrier-specific names onto the ones core knows' do
      expect(described_class.from_webhook(webhook(status: 'cancelled')).status).to eq('failure')
      expect(described_class.from_webhook(webhook(status: 'error')).status).to eq('failure')
    end

    it 'records an unrecognised status as unknown rather than dropping it' do
      event = described_class.from_webhook(webhook(status: 'teleported'))

      expect(event.status).to eq('unknown')
    end

    it 'ignores webhooks that are not tracker updates' do
      expect(described_class.from_webhook('description' => 'batch.created', 'result' => {})).to be_nil
    end

    it 'ignores a tracker with no tracking code to match on' do
      payload = webhook(status: 'in_transit')
      payload['result']['tracking_code'] = nil

      expect(described_class.from_webhook(payload)).to be_nil
    end

    it 'reads the carrier estimate' do
      event = described_class.from_webhook(
        webhook(status: 'in_transit', 'est_delivery_date' => '2026-08-14T00:00:00Z')
      )

      expect(event.estimated_delivery_at).to eq(Time.utc(2026, 8, 14))
    end

    describe 'delivery time' do
      # The webhook usually lands after the parcel arrives, and a return window
      # has to run from the scan rather than from when we heard about it.
      it 'takes the time of the delivering scan' do
        event = described_class.from_webhook(
          webhook(
            status: 'delivered',
            'tracking_details' => [
              { 'status' => 'in_transit', 'datetime' => '2026-08-12T08:00:00Z' },
              { 'status' => 'delivered', 'datetime' => '2026-08-13T14:20:00Z' }
            ]
          )
        )

        expect(event.delivered_at).to eq(Time.utc(2026, 8, 13, 14, 20))
      end

      it 'is blank while the parcel is still moving' do
        event = described_class.from_webhook(
          webhook(
            status: 'in_transit',
            'tracking_details' => [{ 'status' => 'in_transit', 'datetime' => '2026-08-12T08:00:00Z' }]
          )
        )

        expect(event.delivered_at).to be_nil
      end
    end

    it 'translates into the update-tracking argument shape' do
      arguments = described_class.from_webhook(webhook(status: 'in_transit')).to_update_tracking_arguments

      expect(arguments).to include(tracking_code: 'EZ1000000001', tracking_status: 'in_transit')
      expect(arguments.keys).to contain_exactly(
        :tracking_code, :tracking_status, :estimated_delivery_at, :delivered_at, :details
      )
    end

    it 'keeps the carrier detail worth showing an admin' do
      event = described_class.from_webhook(
        webhook(status: 'failure', 'status_detail' => 'address_incorrect')
      )

      expect(event.details).to include('status_detail' => 'address_incorrect', 'carrier' => 'USPS')
    end
  end
end
