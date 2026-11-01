require 'spec_helper'

RSpec.describe Spree::InvoiceRequest, type: :model do
  let(:order) { create(:completed_order_with_totals) }

  it 'normalizes the tax number' do
    request = create(:invoice_request, order: order, tax_id: ' de 123.456-789 ')

    expect(request.tax_id).to eq('DE123456789')
  end

  it 'allows one open request per order' do
    create(:invoice_request, order: order)
    second = build(:invoice_request, order: order)

    expect(second).not_to be_valid
    expect(second.errors.details[:base]).to include(error: :invoice_request_already_open)
  end

  it 'allows a new request once the earlier one is fulfilled' do
    create(:invoice_request, order: order, status: 'fulfilled')

    expect(build(:invoice_request, order: order)).to be_valid
  end
end
