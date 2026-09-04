require 'spec_helper'

RSpec.describe Spree::ShippingLabel, type: :model do
  let(:store) { @default_store }
  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:fulfillment) { order.fulfillments.first }

  it 'accepts a fulfillment and a return as owners, nothing else' do
    expect(build(:shipping_label, owner: fulfillment)).to be_valid
    expect(build(:shipping_label, owner: create(:return, order: create(:shipped_order, store: store)))).to be_valid
    expect(build(:shipping_label, owner: order)).not_to be_valid
  end

  it 'refuses an unknown source or format' do
    expect(build(:shipping_label, owner: fulfillment, source: 'found')).not_to be_valid
    expect(build(:shipping_label, owner: fulfillment, format: 'docx')).not_to be_valid
  end

  describe '#refundable?' do
    it 'covers a purchased label and one the carrier is still deciding on' do
      expect(build(:shipping_label, owner: fulfillment)).to be_refundable
      # Some carriers settle refunds later; re-asking is how a request that
      # never came back is re-driven.
      expect(build(:shipping_label, owner: fulfillment, status: 'refund_requested')).to be_refundable
    end

    it 'excludes a refunded label and one bought elsewhere' do
      expect(build(:shipping_label, owner: fulfillment, status: 'refunded')).not_to be_refundable
      expect(build(:shipping_label, :uploaded, owner: fulfillment)).not_to be_refundable
    end
  end

  describe '.active' do
    it 'excludes refunded labels' do
      live = create(:shipping_label, owner: fulfillment)
      create(:shipping_label, owner: fulfillment, status: 'refunded', refunded_at: Time.current)

      expect(fulfillment.shipping_labels.active).to eq([live])
      expect(fulfillment.active_shipping_label).to eq(live)
    end
  end

  describe 'the file' do
    it 'accepts a PDF and refuses a file whose bytes say otherwise' do
      label = build(:shipping_label, :with_file, owner: fulfillment)
      expect(label).to be_valid

      spoofed = build(:shipping_label, owner: fulfillment)
      spoofed.file.attach(io: StringIO.new('<html><script>alert(1)</script></html>'), filename: 'label.pdf', content_type: 'application/pdf')
      expect(spoofed).not_to be_valid
    end

    it 'knows when the provider copy still has to be fetched' do
      label = build(:shipping_label, owner: fulfillment, metadata: { 'file_url' => 'https://carrier.example/l.pdf' })

      expect(label).to be_file_pending
      expect(label.file_url).to eq('https://carrier.example/l.pdf')
    end
  end

  it 'displays the cost in the label currency' do
    label = build(:shipping_label, owner: fulfillment, cost: 7.25, currency: 'EUR')

    expect(label.display_cost.to_s).to eq('€7.25')
  end
  # The value is whatever the provider wrote, and a browser follows it on a
  # print click — so anything but https is not a label URL.
  describe '#file_url' do
    it 'answers an https URL' do
      label = build(:shipping_label, owner: fulfillment, metadata: { 'file_url' => 'https://carrier.example/l.pdf' })

      expect(label.file_url).to eq('https://carrier.example/l.pdf')
      expect(label).to be_file_pending
    end

    it 'refuses a scheme a browser must not be sent to' do
      %w[javascript:alert(1) file:///etc/passwd http://carrier.example/l.pdf data:text/html,x nonsense].each do |value|
        label = build(:shipping_label, owner: fulfillment, metadata: { 'file_url' => value })

        expect(label.file_url).to be_nil, "expected #{value} to be refused"
        expect(label).not_to be_file_pending
      end
    end
  end
  # A merchant who reroutes a parcel after buying postage still owes that
  # postage back to the carrier who sold it, not to whoever carries the parcel
  # now — and the Manual provider refunds nothing at all.
  describe '#provider' do
    # A carrier gem registers a provider that names the integration holding
    # its credentials; the label resolves back through that pairing.
    let(:selling_provider) do
      Class.new(Spree::FulfillmentProvider::Base) do
        def self.name = 'SpecSellingProvider'
        def self.integration_class = 'Spree::Integration'
        def self.generates_labels? = true
      end
    end

    it 'is the one behind the integration that sold the label' do
      allow(Spree).to receive(:fulfillment_providers).and_return([selling_provider])
      # Stood in rather than created: the only concrete integration in the
      # suite belongs to a provider gem core does not load.
      integration = instance_double(Spree::Integration, type: 'Spree::Integration')
      label = build(:shipping_label, owner: fulfillment)
      allow(label).to receive(:integration).and_return(integration)

      expect(label.provider).to be_a(selling_provider)
    end

    it 'falls back to the parcel own provider for an uploaded label' do
      label = build(:shipping_label, :uploaded, owner: fulfillment, integration: nil)

      expect(label.provider.class).to eq(fulfillment.provider.class)
    end
  end
end
