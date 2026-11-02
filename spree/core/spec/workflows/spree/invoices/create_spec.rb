require 'spec_helper'

RSpec.describe Spree::Invoices::Create do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: 'fv.pdf', content_type: 'application/pdf',
      service_name: Spree.private_storage_service_name
    )
  end
  let(:attributes) do
    { kind: 'invoice', number: 'FV/2026/11/1', issued_on: Date.current, total: order.total, file_signed_id: blob.signed_id }
  end

  subject(:result) { described_class.call(parent: order, attributes: attributes) }

  it "creates an uploaded invoice issued by the order's seller of record" do
    expect(result).to be_success
    expect(result.value).to have_attributes(source: 'uploaded', issuer: store, currency: order.currency, store: store)
    expect(result.value.file).to be_attached
  end

  it 'fulfils the open invoice request' do
    request = create(:invoice_request, order: order)

    expect(result).to be_success
    expect(request.reload).to have_attributes(status: 'fulfilled', invoice: result.value)
  end

  it 'leaves the request open for a receipt' do
    request = create(:invoice_request, order: order)
    described_class.call(parent: order, attributes: attributes.merge(kind: 'receipt'))

    expect(request.reload.status).to eq('open')
  end

  it 'fails with the validation errors' do
    result = described_class.call(parent: order, attributes: attributes.except(:number))

    expect(result).to be_failure
    expect(result.value.errors[:number]).to be_present
  end

  it 'records a commission invoice on a seller payout, issued by the store' do
    payout = create(:seller_payout, store: store)
    result = described_class.call(parent: payout, attributes: attributes)

    expect(result).to be_success
    expect(result.value).to have_attributes(seller_payout: payout, issuer: store, order: nil)
  end

  it 'publishes invoice.created', :events do
    allow(Spree::Events).to receive(:publish).and_call_original
    result

    expect(Spree::Events).to have_received(:publish).with('invoice.created', any_args)
  end
end
