require 'spec_helper'

describe Spree::TaxRate, :type => :model do
  context '#adjust for moss' do
    let(:germany) { create :country, name: "Germany" }
    let(:india) { create :country, name: "India" }
    let(:france) { create :country, name: "France" }
    let(:france_zone) { create :zone_with_country, name: "France Zone" }
    let(:germany_zone) { create :zone_with_country, name: "Germany Zone", default_tax: true }
    let(:india_zone) { create :zone_with_country, name: "India" }
    let(:moss_category) { Spree::TaxCategory.create(name: "Digital Goods") }
    let(:normal_category) { Spree::TaxCategory.create(name: "Analogue Goods") }
    let(:eu_zone) { create(:zone, name: "EU" ) }

    let!(:german_vat) do
      Spree::TaxRate.create(
        name: "German VAT",
        amount: 0.19,
        calculator: Spree::Calculator::DefaultTax.create,
        tax_category: moss_category,
        zone: germany_zone,
        included_in_price: true
      )
    end
    let!(:french_vat) do
      Spree::TaxRate.create(
        name: "French VAT",
        amount: 0.25,
        calculator: Spree::Calculator::DefaultTax.create,
        tax_category: moss_category,
        zone: france_zone,
        included_in_price: true
      )
    end
    let!(:eu_vat) do
      Spree::TaxRate.create(
        name: "EU_VAT",
        amount: 0.19,
        calculator: Spree::Calculator::DefaultTax.create,
        tax_category: normal_category,
        zone: eu_zone,
        included_in_price: true
      )
    end

    let(:download) { create(:product, tax_category: moss_category, price: 100) }
    let(:tshirt) { create(:product, tax_category: normal_category, price: 100) }
    let(:order) { Spree::Order.create }

    before do
      germany_zone.zone_members.create(zoneable: germany)
      france_zone.zone_members.create(zoneable: france)
      india_zone.zone_members.create(zoneable: india)
      eu_zone.zone_members.create(zoneable: germany)
      eu_zone.zone_members.create(zoneable: france)
    end

    context 'a download' do
      before do
        order.contents.add(download.master, 1)
      end

      it 'without an adress costs 100 euros including tax' do
        Spree::TaxRate.adjust(order, order.line_items)
        order.update!
        expect(order.display_total).to eq(Spree::Money.new(100))
        expect(order.included_tax_total).to eq(15.97)
      end

      it 'to germany costs 100 euros including tax' do
        allow(order).to receive(:tax_zone).and_return(germany_zone)
        Spree::TaxRate.adjust(order, order.line_items)
        order.update!
        expect(order.display_total).to eq(Spree::Money.new(100))
        expect(order.included_tax_total).to eq(15.97)
      end

      it 'to france costs more including tax' do
        allow(order).to receive(:tax_zone).and_return(france_zone)
        order.update_line_item_prices!
        Spree::TaxRate.adjust(order, order.line_items)
        order.update!
        expect(order.display_total).to eq(Spree::Money.new(105.04))
        expect(order.included_tax_total).to eq(21.01)
        expect(order.additional_tax_total).to eq(0)
      end

      it 'to somewhere else costs the net amount' do
        allow(order).to receive(:tax_zone).and_return(india_zone)
        order.update_line_item_prices!
        Spree::TaxRate.adjust(order, order.line_items)
        order.update!
        expect(order.included_tax_total).to eq(0)
        expect(order.included_tax_total).to eq(0)
        expect(order.display_total).to eq(Spree::Money.new(84.03))
      end
    end

    context 'a t-shirt' do
      before do
        order.contents.add(tshirt.master, 1)
      end

      it 'to germany costs 100 euros including tax' do
        allow(order).to receive(:tax_zone).and_return(germany_zone)
        Spree::TaxRate.adjust(order, order.line_items)
        order.update!
        expect(order.display_total).to eq(Spree::Money.new(100))
        expect(order.included_tax_total).to eq(15.97)
      end

      it 'to france costs 100 euros including tax' do
        allow(order).to receive(:tax_zone).and_return(france_zone)
        order.update_line_item_prices!
        Spree::TaxRate.adjust(order, order.line_items)
        order.update!
        expect(order.display_total).to eq(Spree::Money.new(100.00))
        expect(order.included_tax_total).to eq(15.97)
        expect(order.additional_tax_total).to eq(0)
      end

      it 'to somewhere else costs the net amount' do
        allow(order).to receive(:tax_zone).and_return(india_zone)
        order.update_line_item_prices!
        Spree::TaxRate.adjust(order, order.line_items)
        order.update!
        expect(order.included_tax_total).to eq(0)
        expect(order.display_total).to eq(Spree::Money.new(84.03))
      end
    end
  end
end
