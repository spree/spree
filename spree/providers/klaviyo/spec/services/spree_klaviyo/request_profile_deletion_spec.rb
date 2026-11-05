require 'spec_helper'

RSpec.describe SpreeKlaviyo::RequestProfileDeletion do
  let(:store) { @default_store }
  let(:other_store) { create(:store) }
  let(:customer) { create(:customer, email: 'ada@example.com') }
  let!(:integration) { create(:klaviyo_integration, :active, store: store) }
  let!(:other_integration) { create(:klaviyo_integration, :active, store: other_store) }

  before { create(:klaviyo_integration, store: create(:store), active: false) }

  it 'is registered on the erasure hook' do
    expect(Spree.hooks.for('customers.anonymize.after_anonymize').map(&:class)).to include(described_class)
  end

  it 'requests the deletion through every active integration, 30 minutes later, with the original email' do
    freeze_time do
      expect { Spree::Customers::Anonymize.call(customer: customer, store: store) }.
        to have_enqueued_job(SpreeKlaviyo::DeleteProfileJob).with(integration, 'ada@example.com').at(30.minutes.from_now).
        and have_enqueued_job(SpreeKlaviyo::DeleteProfileJob).with(other_integration, 'ada@example.com').at(30.minutes.from_now)
    end

    expect(enqueued_jobs.count { |job| job['job_class'] == 'SpreeKlaviyo::DeleteProfileJob' }).to eq(2)
  end

  it 'sends nothing when erasing someone already erased' do
    Spree::Customers::Anonymize.call(customer: customer, store: store)
    clear_enqueued_jobs

    Spree::Customers::Anonymize.call(customer: customer.reload, store: store)

    expect(enqueued_jobs.pluck('job_class')).not_to include('SpreeKlaviyo::DeleteProfileJob')
  end

  it 'unsubscribes the person at once through every active integration' do
    expect { Spree::Customers::Anonymize.call(customer: customer, store: store) }.
      to have_enqueued_job(SpreeKlaviyo::UpdateSubscriptionJob).with(integration, 'ada@example.com', subscribed: false).
      and have_enqueued_job(SpreeKlaviyo::UpdateSubscriptionJob).with(other_integration, 'ada@example.com', subscribed: false)

    unsubscribes = enqueued_jobs.select { |job| job['job_class'] == 'SpreeKlaviyo::UpdateSubscriptionJob' }
    expect(unsubscribes.pluck('scheduled_at')).to all(be_nil)
  end

  # The deleted subscription's event names the store the erasure ran in.
  it "reaches another store's Klaviyo account for a subscription made there", :events do
    create(:newsletter_subscriber, store: other_store, email: 'ada@example.com', customer: customer)
    Spree::Current.store = store

    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
      Spree::Customers::Anonymize.call(customer: customer, store: store)
    end

    other_store_unsubscribes = enqueued_jobs.select do |job|
      job['job_class'] == 'SpreeKlaviyo::UpdateSubscriptionJob' &&
        job['arguments'].first['_aj_globalid'].end_with?("/#{other_integration.id}")
    end
    expect(other_store_unsubscribes).not_to be_empty
  end

  it "enqueues the erasure's own unsubscribes at once", :events do
    create(:newsletter_subscriber, store: store, email: 'ada@example.com', customer: customer)
    Spree::Current.store = store

    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
      Spree::Customers::Anonymize.call(customer: customer, store: store)
    end

    unsubscribe = enqueued_jobs.find { |job| job['job_class'] == 'SpreeKlaviyo::UpdateSubscriptionJob' }
    expect(unsubscribe).to be_present
    expect(unsubscribe['scheduled_at']).to be_nil
    expect(unsubscribe['arguments'].second).to eq('ada@example.com')
  end
end
