require 'spec_helper'

module Spree
  describe VatPriceCalculator do
    let!(:tax_category) { Spree::TaxCategory.create(name: 'FirstCategory', is_default: false) }
    let!(:second_tax_category) { Spree::TaxCategory.create(name: 'SecondCategory', is_default: true) }
    let!(:variant) { create(:variant, tax_category: second_tax_category) }
    let!(:default_zone) { Spree::Zone.create(default_tax: true, name: 'DefaultZone', kind: 'country') }
    let!(:zone) { Spree::Zone.create(default_tax: false, name: 'TestZone', kind: 'country') }
    let!(:country) { Spree::Country.create(name: 'Monaco', iso_name: 'MONACO') }
    let!(:foreign_country) { Spree::Country.create(name: 'Poland', iso_name: 'POLAND') }
    let!(:zone_member) { Spree::ZoneMember.create(zone: default_zone, zoneable: country, zoneable_id: 2) }
    let!(:second_zone_member) { Spree::ZoneMember.create(zone: zone, zoneable: country, zoneable_id: 1) }
    let!(:tax_rate) { create(:tax_rate, zone: zone, included_in_price: true, tax_category: second_tax_category, amount: 0.05) }
    let(:amount) { 10 }
    let(:price) { Spree::Price.new variant: variant, amount: amount }
    let(:price_options) { { tax_zone: zone } }

    subject(:calculator) { Spree::VatPriceCalculator.new }

    context 'Inside default vat zone' do
      it 'returns amount' do
        expect(calculator.call(amount, price_options)).to eq(10)
      end
    end

    context 'Outside default vat zone' do
      let(:options) { price_options.merge(tax_category: second_tax_category) }
      it 'returns amount + vat' do
        expect(calculator.call(amount, options)).to eq(10.5)
      end
    end
  end
end
