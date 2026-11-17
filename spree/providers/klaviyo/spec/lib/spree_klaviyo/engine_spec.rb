require 'spec_helper'

RSpec.describe SpreeKlaviyo::Engine do
  it 'registers the subscribers' do
    expect(Spree.subscribers).to include(
      SpreeKlaviyo::CustomerSubscriber, SpreeKlaviyo::NewsletterSubscriber, SpreeKlaviyo::OrderSubscriber,
      SpreeKlaviyo::FulfillmentSubscriber, SpreeKlaviyo::ReturnSubscriber
    )
  end

  it 'registers the erasure hook handler' do
    expect(Spree.hooks.for('customers.anonymize.after_anonymize')).to include(an_instance_of(SpreeKlaviyo::RequestProfileDeletion))
  end

  it 'registers the integration' do
    expect(Spree.integrations).to include('Spree::Integrations::Klaviyo')
  end
end
