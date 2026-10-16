require 'spec_helper'

describe Spree::TaxExemptionReason, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }
  let(:reason) { create(:tax_exemption_reason, store: store, code: 'G') }

  it 'keeps codes unique within a store' do
    reason

    expect(build(:tax_exemption_reason, store: store, code: 'G')).not_to be_valid
    expect(build(:tax_exemption_reason, store: create(:store), code: 'G')).to be_valid
  end

  context 'when a certificate records it' do
    before { create(:tax_exemption_certificate, company: create(:company, store: store), reason_code: reason.code) }

    it 'keeps its code' do
      expect(reason.update(code: 'N')).to be(false)
      expect(reason.errors.details[:code]).to include(error: :in_use)
    end

    it 'can still be renamed' do
      expect(reason.update(name: 'Resale')).to be(true)
    end

    it 'cannot be deleted' do
      expect(reason.can_be_deleted?).to be(false)
      expect(reason.destroy).to be(false)
    end
  end

  # Certificates are found through their company's store, so another store
  # recording the same code does not pin this one.
  it 'ignores certificates of another store' do
    other_store = create(:store)
    create(:tax_exemption_certificate, company: create(:company, store: other_store), reason_code: reason.code)

    expect(reason.can_be_deleted?).to be(true)
  end
end
