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
    it 'is true only for a purchased label that has not been refunded' do
      expect(build(:shipping_label, owner: fulfillment)).to be_refundable
      expect(build(:shipping_label, owner: fulfillment, status: 'refund_requested')).not_to be_refundable
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
end
