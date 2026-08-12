require 'spec_helper'

RSpec.describe Spree::DigitalDelivery do
  it 'is a redirect when it carries a url' do
    delivery = described_class.new(redirect_url: 'https://example.com/file')

    expect(delivery).to be_redirect
    expect(delivery).to be_present
  end

  it 'is not a redirect when it carries an inline value' do
    delivery = described_class.new(inline_value: 'KEY-123', content_type: 'text/plain')

    expect(delivery).not_to be_redirect
    expect(delivery).to be_present
  end

  it 'is absent when it carries nothing' do
    expect(described_class.new).not_to be_present
  end
end
