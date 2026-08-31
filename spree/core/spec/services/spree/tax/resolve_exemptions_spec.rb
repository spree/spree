require 'spec_helper'

describe Spree::Tax::ResolveExemptions do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }

  it 'resolves nothing for a consumer sale' do
    result = described_class.call(order: order)

    expect(result).to be_success
    expect(result.value).to eq([])
  end

  context 'for a business customer' do
    let(:store) { @default_store }
    let(:company) { create(:company, store: store) }
    # The purchase points at a division; certificates resolve through its
    # legal entity — the parent company node.
    let(:division) { create(:company, store: store, kind: 'division', parent: company) }
    let(:germany) { create(:country, iso: 'DE', name: 'Germany') }
    let(:berlin) { create(:state, country: germany, abbr: 'BE', name: 'Berlin') }

    before do
      order.update!(company: division,
                    ship_address: create(:address, country: germany, state: berlin),
                    bill_address: create(:address, country: germany, state: berlin))
    end

    # Certificates stay on file but stop applying while the policy says the
    # business may not act commercially.
    it 'resolves nothing while the company is not policy-active' do
      create(:tax_exemption_certificate, :verified, company: company,
                                                    reason_code: 'resale', certificate_number: 'DE-RESALE-9',
                                                    country_code: germany&.iso, state_code: berlin&.abbr)

      with_company_activation_policy(inactive: [company]) do
        expect(described_class.call(order: order.reload).value).to eq([])
      end
    end

    it 'turns an active certificate into a claim' do
      create(:tax_exemption_certificate, :verified, company: company,
                                                    reason_code: 'resale', certificate_number: 'DE-RESALE-1',
                                                    country_code: germany&.iso, state_code: berlin&.abbr)

      exemption = described_class.call(order: order.reload).value.sole

      expect(exemption.reason_code).to eq('resale')
      expect(exemption.certificate_number).to eq('DE-RESALE-1')
      expect(exemption.country_code).to eq('DE')
      expect(exemption.state_code).to eq('BE')
    end

    it 'returns one entry per certificate' do
      create(:tax_exemption_certificate, :verified, company: company, reason_code: 'resale')
      create(:tax_exemption_certificate, :verified, company: company, reason_code: 'government')

      expect(described_class.call(order: order.reload).value.map(&:reason_code)).
        to contain_exactly('resale', 'government')
    end

    it 'ignores a certificate awaiting verification' do
      create(:tax_exemption_certificate, company: company)

      expect(described_class.call(order: order.reload).value).to eq([])
    end

    it 'ignores one whose date has passed' do
      create(:tax_exemption_certificate, :expired, company: company)

      expect(described_class.call(order: order.reload).value).to eq([])
    end

    it 'ignores one held for another jurisdiction' do
      create(:tax_exemption_certificate, :verified, company: company, country_code: create(:country, iso: 'FR')&.iso)

      expect(described_class.call(order: order.reload).value).to eq([])
    end

    # Tax needs a destination before an exemption can be scoped to one.
    it 'resolves nothing before the buyer gives an address' do
      order.update!(ship_address: nil, bill_address: nil)
      create(:tax_exemption_certificate, :verified, company: company)

      expect(described_class.call(order: order.reload).value).to eq([])
    end
  end

  it 'is the registered seam merchants swap' do
    expect(Spree.tax_resolve_exemptions_service).to eq(described_class)
  end

  context 'when an application swaps the seam' do
    let(:custom_service) do
      Class.new do
        prepend Spree::ServiceModule::Base

        def call(order:)
          success([Spree::TaxExemption.new(reason_code: 'resale', certificate_number: 'CERT-1')])
        end
      end
    end

    before { Spree::Dependencies.tax_resolve_exemptions_service = custom_service }
    after { Spree::Dependencies.tax_resolve_exemptions_service = described_class }

    it 'returns the application entries to the caller' do
      exemptions = Spree.tax_resolve_exemptions_service.new.call(order: order).value

      expect(exemptions.map(&:reason_code)).to eq(['resale'])
    end
  end
end
