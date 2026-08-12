require 'spec_helper'

describe Spree::TaxExemptionCertificate, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }

  it 'reaches the store through its company' do
    expect(create(:tax_exemption_certificate, company: company).store).to eq(store)
  end

  it 'starts pending' do
    expect(create(:tax_exemption_certificate, company: company)).to be_pending
  end

  describe '.active' do
    it 'includes a verified certificate with no expiry' do
      certificate = create(:tax_exemption_certificate, :verified, company: company)

      expect(described_class.active).to include(certificate)
    end

    it 'excludes one that has not been verified' do
      certificate = create(:tax_exemption_certificate, company: company)

      expect(described_class.active).not_to include(certificate)
    end

    # The date is the fact — no job writes 'expired', so the scope has to be
    # what keeps a lapsed certificate out of resolution.
    it 'excludes a verified certificate whose date has passed' do
      certificate = create(:tax_exemption_certificate, :expired, company: company)

      expect(certificate).to be_verified
      expect(certificate).to be_lapsed
      expect(described_class.active).not_to include(certificate)
    end

    it 'includes one expiring in the future' do
      certificate = create(:tax_exemption_certificate, :verified, company: company, expires_at: 1.year.from_now)

      expect(described_class.active).to include(certificate)
    end
  end

  describe '.for_address' do
    let(:germany) { create(:country, iso: 'DE', name: 'Germany') }
    let(:berlin) { create(:state, country: germany, abbr: 'BE', name: 'Berlin') }
    let(:address) { create(:address, country: germany, state: berlin) }

    it 'matches a certificate naming no jurisdiction' do
      certificate = create(:tax_exemption_certificate, company: company)

      expect(described_class.for_address(address)).to include(certificate)
    end

    it 'matches one naming the country' do
      certificate = create(:tax_exemption_certificate, company: company, country_iso: germany&.iso)

      expect(described_class.for_address(address)).to include(certificate)
    end

    it 'matches one naming the exact state' do
      certificate = create(:tax_exemption_certificate, company: company, country_iso: germany&.iso, state_code: berlin&.abbr)

      expect(described_class.for_address(address)).to include(certificate)
    end

    it 'excludes one naming another state of the same country' do
      other = create(:state, country: germany, abbr: 'HH', name: 'Hamburg')
      certificate = create(:tax_exemption_certificate, company: company, country_iso: germany&.iso, state_code: other&.abbr)

      expect(described_class.for_address(address)).not_to include(certificate)
    end

    it 'excludes one naming another country' do
      certificate = create(:tax_exemption_certificate, company: company, country_iso: create(:country, iso: 'FR')&.iso)

      expect(described_class.for_address(address)).not_to include(certificate)
    end

    # The reason the jurisdiction is a code rather than a country row: an
    # unrecognised code used to resolve to nil, and nil claims every country
    # here — so a typo turned one state's certificate into a worldwide
    # exemption. It must narrow to nothing instead.
    it 'never matches when the country code is one nothing recognises' do
      certificate = create(:tax_exemption_certificate, company: company, country_iso: 'ZZ')

      expect(described_class.for_address(address)).not_to include(certificate)
    end

    it 'stores the jurisdiction upcased however it was entered' do
      certificate = create(:tax_exemption_certificate, company: company, country_iso: 'de', state_code: 'be')

      expect(certificate.country_iso).to eq('DE')
      expect(certificate.state_code).to eq('BE')
    end
  end

  describe '#can_be_deleted?' do
    it 'refuses once verified — revoke instead' do
      expect(create(:tax_exemption_certificate, :verified, company: company).can_be_deleted?).to be(false)
    end

    it 'allows a pending one' do
      expect(create(:tax_exemption_certificate, company: company).can_be_deleted?).to be(true)
    end
  end

  it 'is destroyed with its company' do
    create(:tax_exemption_certificate, company: company)

    expect { company.destroy }.to change(described_class, :count).by(-1)
  end
end
