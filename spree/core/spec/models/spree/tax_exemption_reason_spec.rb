require 'spec_helper'

describe Spree::TaxExemptionReason, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }
  let(:reason) { create(:tax_exemption_reason, store: store, code: 'G') }

  it 'keeps codes unique within a store, whatever their case' do
    reason

    expect(build(:tax_exemption_reason, store: store, code: ' g ')).not_to be_valid
    expect(build(:tax_exemption_reason, store: create(:store), code: 'G')).to be_valid
  end

  context 'when a certificate records it' do
    let!(:certificate) { create(:tax_exemption_certificate, company: create(:company, store: store), tax_exemption_reason: reason) }

    it 'can change its code, which the certificate follows' do
      expect(reason.update(code: 'N')).to be(true)
      expect(certificate.reload.tax_exemption_reason.code).to eq('N')
    end

    it 'cannot be deleted' do
      expect(reason.can_be_deleted?).to be(false)
      expect(reason.destroy).to be(false)
      expect(reason.errors.details[:base]).to include(error: :in_use)
    end
  end

  describe '.find_or_create_by_code_or_name!' do
    it 'finds a reason by its code' do
      reason

      expect(store.tax_exemption_reasons.find_or_create_by_code_or_name!(code: 'g', name: 'Resale')).to eq(reason)
    end

    it 'finds a reason by its name' do
      reason.update!(name: 'Resale')

      expect(store.tax_exemption_reasons.find_or_create_by_code_or_name!(code: 'RESALE', name: 'Resale')).to eq(reason)
    end

    it 'prefers the reason holding the code over one holding the name' do
      reason
      create(:tax_exemption_reason, store: store, code: 'WHOLESALE', name: 'Resale')

      expect(store.tax_exemption_reasons.find_or_create_by_code_or_name!(code: 'G', name: 'Resale')).to eq(reason)
    end

    it 'creates one when neither is taken' do
      created = store.tax_exemption_reasons.find_or_create_by_code_or_name!(code: 'e', name: 'Educational')

      expect(created).to be_persisted
      expect(created.code).to eq('E')
    end
  end
end
