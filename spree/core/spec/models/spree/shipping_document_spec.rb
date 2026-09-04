require 'spec_helper'

RSpec.describe Spree::ShippingDocument do
  it 'defaults to a generic kind when the carrier does not name one' do
    expect(described_class.new(url: 'https://carrier.example/doc.pdf').kind).to eq('form')
  end

  it 'requires somewhere to read the document' do
    expect(described_class.new(kind: 'cn23')).not_to be_valid
  end

  # The rendered shape is the API contract, so it is pinned here rather than
  # left to whatever a serializer happens to do with the object.
  it 'renders as the kind and the url' do
    document = described_class.new(kind: 'commercial_invoice', url: 'https://carrier.example/ci.pdf')

    expect(document.as_json).to eq(kind: 'commercial_invoice', url: 'https://carrier.example/ci.pdf')
  end
end
