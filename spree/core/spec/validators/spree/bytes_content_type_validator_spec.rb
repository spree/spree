require 'spec_helper'

describe Spree::BytesContentTypeValidator do
  subject(:validator) do
    described_class.new(attributes: [:po_document], in: %w[application/pdf image/jpeg])
  end

  let(:cart) { FactoryBot.create(:cart) }

  def attach(io:, filename:, content_type:)
    cart.po_document.attach(io: StringIO.new(io), filename: filename, content_type: content_type)
  end

  it 'accepts a PDF whose bytes are a PDF' do
    attach(io: '%PDF-1.4 purchase order', filename: 'po.pdf', content_type: 'application/pdf')

    validator.validate(cart)

    expect(cart.errors[:po_document]).to be_empty
  end

  it 'refuses a script dressed as a PDF' do
    attach(io: "#!/bin/sh\nrm -rf /\n", filename: 'po.pdf', content_type: 'application/pdf')

    validator.validate(cart)

    expect(cart.errors[:po_document].join).to include(Spree.t(:attachment_content_type_mismatch))
  end

  it 'does not shell out to the Unix file command' do
    expect(Open3).not_to receive(:capture2)

    attach(io: '%PDF-1.4 purchase order', filename: 'po.pdf', content_type: 'application/pdf')
    validator.validate(cart)
  end
end
