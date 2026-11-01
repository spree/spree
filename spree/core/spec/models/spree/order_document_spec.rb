require 'spec_helper'

RSpec.describe Spree::OrderDocument, type: :model do
  let(:order) { create(:completed_order_with_totals) }

  it 'is private to staff by default' do
    expect(create(:order_document, order: order).customer_visible).to be(false)
  end

  it 'requires a label and a file' do
    document = build(:order_document, order: order, label: ' ')
    document.file.detach

    expect(document).not_to be_valid
    expect(document.errors[:label]).to be_present
    expect(document.errors[:file]).to be_present
  end

  it 'refuses a script dressed as a PDF' do
    document = build(:order_document, order: order)
    document.file.attach(io: StringIO.new("#!/bin/sh\nrm -rf /\n"), filename: 'po.pdf', content_type: 'application/pdf')

    expect(document).not_to be_valid
    expect(document.errors.details[:file]).to include(error: :spree_content_type_not_allowed)
  end

  it "refuses hiding the buyer's own upload from them" do
    document = create(:order_document, order: order, uploaded_by: create(:customer), customer_visible: true)

    expect(document.update(customer_visible: false)).to be(false)
  end

  it 'knows when the buyer uploaded it' do
    document = build(:order_document, order: order, uploaded_by: order.customer || create(:customer))

    expect(document.uploaded_by_customer?).to be(true)
  end
end
