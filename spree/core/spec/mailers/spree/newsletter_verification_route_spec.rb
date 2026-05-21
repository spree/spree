require 'spec_helper'

RSpec.describe 'Newsletter verification route helper' do
  let(:store) { create(:store) }
  let(:subscriber) { create(:newsletter_subscriber, store: store) }

  it 'builds a storefront newsletter verification URL for the subscriber token' do
    url = Rails.application.routes.url_helpers.verify_newsletter_subscribers_url(subscriber)

    expect(url).to eq("#{store.storefront_url}/newsletter/verify?token=#{subscriber.verification_token}")
  end

  it 'honors an explicit host override' do
    url = Rails.application.routes.url_helpers.verify_newsletter_subscribers_url(subscriber, host: 'https://custom.example.com')

    expect(url).to eq("https://custom.example.com/newsletter/verify?token=#{subscriber.verification_token}")
  end
end
