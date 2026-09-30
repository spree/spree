require 'spec_helper'

RSpec.describe Spree::Events::Catalog do
  describe 'Entry#payload_serializer' do
    subject(:catalog) { described_class.new }

    it "falls back to the model's Store serializer" do
      catalog.declare(Spree::Order, :placed)

      expect(catalog.find('order.placed').payload_serializer).to eq(Spree::Api::V3::OrderSerializer)
    end

    it 'uses the declared serializer' do
      catalog.declare(Spree::NewsletterSubscriber, :unsubscribe_requested,
                      serializer: 'Spree::Api::V3::NewsletterSubscriberRequestEventSerializer')

      expect(catalog.find('newsletter_subscriber.unsubscribe_requested').payload_serializer)
        .to eq(Spree::Api::V3::NewsletterSubscriberRequestEventSerializer)
    end
  end

  it 'resolves every serializer an event names, and never an Admin one' do
    entries = Spree::Events.catalog.all
    missing = entries.select { |entry| entry.serializer_name && !entry.serializer_name.safe_constantize }.map(&:name)
    admin_shaped = entries.select { |entry| entry.payload_serializer&.name.to_s.include?('::Admin::') }.map(&:name)

    expect(missing).to be_empty, "events naming a serializer that does not exist: #{missing.join(', ')}"
    expect(admin_shaped).to be_empty, "events with an Admin payload: #{admin_shaped.join(', ')}"
  end
end
