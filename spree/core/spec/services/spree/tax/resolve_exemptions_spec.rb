require 'spec_helper'

describe Spree::Tax::ResolveExemptions do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }

  it 'resolves nothing, core storing no certificates' do
    result = described_class.call(order: order)

    expect(result).to be_success
    expect(result.value).to eq([])
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
