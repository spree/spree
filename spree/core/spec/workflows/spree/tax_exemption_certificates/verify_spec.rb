require 'spec_helper'

RSpec.describe Spree::TaxExemptionCertificates::Verify do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }
  let(:certificate) { create(:tax_exemption_certificate, company: company) }
  let(:staff) { create(:admin_user) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  it 'accepts a pending certificate and records who did' do
    result = described_class.call(certificate: certificate, verified_by: staff)

    expect(result).to be_success
    expect(result.value).to be_verified
    expect(result.value.verified_at).to be_present
    expect(result.value.verified_by).to eq(staff)
  end

  it 'makes the certificate count at estimate time' do
    expect { described_class.call(certificate: certificate) }.
      to change { Spree::TaxExemptionCertificate.active.include?(certificate.reload) }.from(false).to(true)
  end

  it 'refuses anything not pending' do
    revoked = create(:tax_exemption_certificate, company: company, status: 'revoked')

    result = described_class.call(certificate: revoked)

    expect(result).to be_failure
    expect(revoked.reload).to be_revoked
  end

  it 'publishes the event', :events do
    allow(Spree::Events).to receive(:publish)

    described_class.call(certificate: certificate)

    expect(Spree::Events).to have_received(:publish).with('tax_exemption_certificate.verified', any_args)
  end

  # The reason this is a workflow at all: somewhere to refuse before the
  # certificate starts exempting sales.
  describe 'the validate hook' do
    it 'lets a handler veto, writing nothing' do
      Spree.hooks.register('tax_exemption_certificates.verify.validate') do |flow|
        flow.reject!('registry check failed')
      end

      result = described_class.call(certificate: certificate)

      expect(result).to be_failure
      expect(result.error.value).to eq('registry check failed')
      expect(certificate.reload).to be_pending
      expect(certificate.verified_at).to be_nil
    end

    it 'runs after_verify once accepted' do
      seen = nil
      Spree.hooks.register('tax_exemption_certificates.verify.after_verify') do |flow|
        seen = flow.certificate.status
      end

      described_class.call(certificate: certificate)

      expect(seen).to eq('verified')
    end
  end

  it 'is reachable through the dependency seam' do
    expect(Spree.tax_exemption_certificate_verify_workflow).to eq(described_class)
  end
end
