require 'spec_helper'

RSpec.describe Spree::SignedIdAttachments do
  let(:certificate) { create(:tax_exemption_certificate) }

  def pdf_blob(service_name: Spree.private_storage_service_name)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new('%PDF-1.4 certificate'), filename: 'certificate.pdf',
                                           content_type: 'application/pdf', service_name: service_name)
  end

  it 'attaches a file through <slot>_signed_id and removes it with nil' do
    certificate.update!(document_signed_id: pdf_blob.signed_id)
    expect(certificate.reload.document).to be_attached

    certificate.update!(document_signed_id: nil)
    expect(certificate.reload.document).not_to be_attached
  end

  it 'refuses a file stored with the other visibility' do
    certificate.document_signed_id = pdf_blob(service_name: 'local').signed_id

    expect(certificate).not_to be_valid
    expect(certificate.errors[:document]).to include('must be uploaded with private visibility')
  end

  it 'names the API field a slot is written with' do
    expect(Spree::TaxExemptionCertificate.signed_id_attribute_for(:document)).to eq('document_signed_id')
    expect(Spree::TaxExemptionCertificate.signed_id_attribute_for(:certificate_number)).to be_nil
  end
end
