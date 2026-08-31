require 'spec_helper'

describe Spree::BytesContentTypeValidator do
  subject(:validator) do
    described_class.new(attributes: [:po_document], in: %w[application/pdf image/jpeg])
  end

  let(:cart) { FactoryBot.create(:cart) }

  # Direct uploads keep the client's declared type and mark the blob
  # identified, so attach will not ask Marcel again. That is the path the
  # validator has to cover on its own.
  def attach_declared(io:, filename:, content_type:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(io),
      filename: filename,
      content_type: content_type,
      identify: false,
      service_name: Spree.private_storage_service_name
    )
    cart.po_document.attach(blob)
    cart.errors.clear
  end

  it 'accepts a PDF whose bytes are a PDF' do
    attach_declared(io: '%PDF-1.4 purchase order', filename: 'po.pdf', content_type: 'application/pdf')

    validator.validate(cart)

    expect(cart.errors[:po_document]).to be_empty
  end

  it 'refuses a script dressed as a PDF' do
    attach_declared(io: "#!/bin/sh\nrm -rf /\n", filename: 'po.pdf', content_type: 'application/pdf')

    validator.validate(cart)

    expect(cart.errors[:po_document].join).to include(Spree.t(:attachment_content_type_mismatch))
  end

  it 'does not shell out to the Unix file command' do
    expect(Open3).not_to receive(:capture2)

    attach_declared(io: '%PDF-1.4 purchase order', filename: 'po.pdf', content_type: 'application/pdf')
    validator.validate(cart)
  end
end
