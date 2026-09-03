require 'spec_helper'

RSpec.describe Spree::ShippingLabels::StoreFile do
  subject(:service) { described_class.new }

  let(:store) { @default_store }
  let(:fulfillment) { create(:order_ready_to_ship, store: store).fulfillments.first }
  let(:label) { create(:shipping_label, owner: fulfillment, metadata: { 'file_url' => 'https://carrier.example/label.pdf' }) }

  def http_response(code, body)
    Net::HTTPResponse::CODE_TO_OBJ[code].new('1.1', code, 'x').tap do |response|
      allow(response).to receive(:body).and_return(body)
    end
  end

  it 'fetches the provider copy into private storage' do
    allow(SsrfFilter).to receive(:get).with('https://carrier.example/label.pdf', anything).
      and_return(http_response('200', "%PDF-1.4\n%label\n"))

    result = service.call(shipping_label: label)

    expect(result).to be_success
    expect(label.reload.file).to be_attached
    expect(label.file.filename.to_s).to end_with('.pdf')
    expect(label).not_to be_file_pending
  end

  it 'fails without touching the label when the carrier answers an error' do
    allow(SsrfFilter).to receive(:get).and_return(http_response('404', ''))

    result = service.call(shipping_label: label)

    expect(result).to be_failure
    expect(result.error.to_s).to include('404')
    expect(label.reload.file).not_to be_attached
  end

  it 'refuses a file whose bytes are not a label' do
    allow(SsrfFilter).to receive(:get).and_return(http_response('200', '<html>nope</html>'))

    expect(service.call(shipping_label: label)).to be_failure
    expect(label.reload.file).not_to be_attached
  end

  it 'is a no-op once the file is stored' do
    stored = create(:shipping_label, :with_file, owner: fulfillment)
    expect(SsrfFilter).not_to receive(:get)

    expect(service.call(shipping_label: stored)).to be_success
  end
end
