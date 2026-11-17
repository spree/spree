require 'spec_helper'

RSpec.describe 'Klaviyo jobs' do
  let(:store) { @default_store }
  let(:integration) { create(:klaviyo_integration, :active, store: store) }
  let(:tombstone) { "anonymized-1@#{Spree::Customers::Anonymize::REDACTED_DOMAIN}" }

  describe SpreeKlaviyo::SyncProfileJob do
    let(:customer) { create(:customer, email: 'ada@example.com') }

    it "imports a customer's profile" do
      expect(integration).to receive(:import_profile) do |profile|
        expect(profile.email).to eq('ada@example.com')
        expect(profile.external_id).to eq(customer.prefixed_id)
      end

      described_class.perform_now(integration, customer)
    end

    it 'sends the database id when the integration asks for it' do
      integration.preferred_use_database_ids_as_external_ids = true

      expect(integration).to receive(:import_profile) { |profile| expect(profile.external_id).to eq(customer.id.to_s) }

      described_class.perform_now(integration, customer)
    end

    it "imports an order's profile" do
      order = create(:completed_order_with_totals, store: store)

      expect(integration).to receive(:import_profile) { |profile| expect(profile.email).to eq(order.email) }

      described_class.perform_now(integration, order)
    end

    it 'does not sync an anonymized customer' do
      customer.update_columns(anonymized_at: Time.current)

      expect(integration).not_to receive(:import_profile)

      described_class.perform_now(integration, customer)
    end

    it 'sends nothing for a tombstone email' do
      order = create(:completed_order_with_totals, store: store)
      # An erasure rewrites the customer and their orders alike.
      order.update_column(:email, tombstone)
      order.customer.update_column(:email, tombstone)

      expect(integration).not_to receive(:import_profile)

      described_class.perform_now(integration, order)
    end
  end

  describe SpreeKlaviyo::UpdateSubscriptionJob do
    it 'subscribes' do
      create(:newsletter_subscriber, store: store, email: 'ada@example.com')
      expect(integration).to receive(:subscribe).with('ada@example.com')

      described_class.perform_now(integration, 'ada@example.com', subscribed: true)
    end

    it 'skips a subscribe whose subscriber was removed while it waited' do
      expect(integration).not_to receive(:subscribe)

      described_class.perform_now(integration, 'ada@example.com', subscribed: true)
    end

    it 'unsubscribes' do
      expect(integration).to receive(:unsubscribe).with('ada@example.com')

      described_class.perform_now(integration, 'ada@example.com', subscribed: false)
    end

    it 'sends nothing for a tombstone email' do
      expect(integration).not_to receive(:subscribe)
      expect(integration).not_to receive(:unsubscribe)

      described_class.perform_now(integration, tombstone, subscribed: true)
      described_class.perform_now(integration, tombstone, subscribed: false)
    end

    describe 'an unsubscribe still rate-limited' do
      let(:reports) { [] }
      let(:rate_limited) { KlaviyoAPI::ApiError.new(code: 429, response_headers: { 'Retry-After' => '60' }) }

      before do
        allow(Rails.error).to receive(:report) { |error, **options| reports << [error, options] }
        allow_any_instance_of(Spree::Integrations::Klaviyo).to receive(:unsubscribe).and_raise(rate_limited)
        allow_any_instance_of(Spree::Integrations::Klaviyo).to receive(:subscribe).and_raise(rate_limited)
      end

      def run_after(elapsed, subscribed:)
        job_data = described_class.new(integration, 'ada@example.com', subscribed: subscribed).serialize

        travel(elapsed) do
          clear_enqueued_jobs
          ActiveJob::Base.execute(job_data)
        end
      end

      it 'is rescheduled while the retry still lands within 20 minutes' do
        run_after(18.minutes, subscribed: false)

        expect(enqueued_jobs.size).to eq(1)
        expect(reports).to be_empty
      end

      it "is reported when Klaviyo's Retry-After would carry it past 20 minutes" do
        run_after(19.minutes + 30.seconds, subscribed: false)

        expect(enqueued_jobs).to be_empty
        expect(reports.size).to eq(1)
      end

      it 'is reported and not rescheduled 21 minutes after being enqueued' do
        run_after(21.minutes, subscribed: false)

        expect(enqueued_jobs).to be_empty
        expect(reports.size).to eq(1)
      end

      it 'keeps its deadline across reschedules' do
        job_data = described_class.new(integration, 'ada@example.com', subscribed: false).serialize

        travel(10.minutes) { ActiveJob::Base.execute(job_data) }
        rescheduled = enqueued_jobs.last
        expect(rescheduled['klaviyo_first_enqueued_at']).to eq(job_data['klaviyo_first_enqueued_at'])

        travel(21.minutes) do
          clear_enqueued_jobs
          ActiveJob::Base.execute(rescheduled)
        end
        expect(enqueued_jobs).to be_empty
        expect(reports.size).to eq(1)
      end

      it 'keeps rescheduling a subscribe however long it waits' do
        create(:newsletter_subscriber, store: store, email: 'ada@example.com')
        run_after(2.hours, subscribed: true)

        expect(enqueued_jobs.size).to eq(1)
        expect(reports).to be_empty
      end
    end
  end

  describe SpreeKlaviyo::TrackEventJob do
    let(:order) { create(:completed_order_with_totals, store: store) }

    it 'records the metric for the record' do
      expect(integration).to receive(:create_event) do |event|
        expect(event.metric).to eq('Placed Order')
        expect(event.properties[:NotifyCustomer]).to be(false)
      end

      described_class.perform_now(integration, order, 'placed_order', notify_customer: false)
    end

    it "records Return Refunded under the Spree event's id and time" do
      return_record = create(:received_return, store: store, order: order)

      expect(integration).to receive(:create_event) do |event|
        expect(event.unique_id).to eq('evt_1')
        expect(event.time).to eq(Time.zone.parse('2026-11-04T15:30:00Z'))
      end

      described_class.perform_now(integration, return_record, 'return_refunded', event_id: 'evt_1',
                                                                                 published_at: Time.zone.parse('2026-11-04T15:30:00Z'))
    end

    # Spree skipped its own email when the order was placed, so the queued
    # event is the customer's only one.
    it 'still sends an event queued before the integration was turned off' do
      integration.update_column(:active, false)

      expect(integration).to receive(:create_event)

      described_class.perform_now(integration, order, 'placed_order')
    end

    it 'refuses a metric it does not know' do
      expect { described_class.perform_now(integration, order, 'Kernel') }.to raise_error(ArgumentError)
    end

    it 'sends nothing for a tombstone email' do
      order.update_column(:email, tombstone)
      order.customer&.update_column(:email, tombstone)

      expect(integration).not_to receive(:create_event)

      described_class.perform_now(integration, order, 'canceled_order')
    end
  end

  describe 'SpreeKlaviyo::BaseJob.tombstone?' do
    it 'matches the tombstone domain whatever its case' do
      expect(SpreeKlaviyo::BaseJob.tombstone?('anonymized-1@INVALID')).to be(true)
      expect(SpreeKlaviyo::BaseJob.tombstone?('ada@example.com')).to be(false)
    end
  end

  describe SpreeKlaviyo::DeleteProfileJob do
    it 'requests the deletion' do
      expect(integration).to receive(:request_profile_deletion).with('ada@example.com')

      described_class.perform_now(integration, 'ada@example.com')
    end

    it 'sends nothing for a tombstone email' do
      expect(integration).not_to receive(:request_profile_deletion)

      described_class.perform_now(integration, tombstone)
    end
  end
end
