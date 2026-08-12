require 'spec_helper'

# The cross-border matrix. A tax-inclusive price is expressed in some country's
# VAT, so shipping elsewhere has to restate it: the home rate out, the
# destination's on. Nothing covered this from the cart side before — the existing
# coverage in tax_rate_spec.rb drives the order path.
describe Spree::VatPriceCalculation, type: :model do
  let(:store) { @default_store }
  let(:germany) { Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE', name: 'Germany') }
  let(:france) { Spree::Country.find_by(iso: 'FR') || create(:country, iso: 'FR', name: 'France') }
  let(:japan) { Spree::Country.find_by(iso: 'JP') || create(:country, iso: 'JP', name: 'Japan') }
  let(:category) { create(:tax_category, name: "Goods #{Time.current.to_f}") }

  # Prices are quoted including German VAT, so Germany is the home zone.
  let(:home_market) { store.default_market }

  before do
    home_market.update!(countries: [germany])
    create(:tax_rate, name: 'DE 19% incl', amount: 0.19, tax_category: category,
                      country_iso: germany&.iso, included_in_price: true, store: store)
  end

  let(:variant) { create(:variant, price: 100, product: create(:product, tax_category: category)) }
  let(:price) { variant.prices.find_by(currency: 'USD', price_list_id: nil) }

  def gross_for(country, market: home_market)
    price.price_including_vat_for(country: country, market: market)
  end

  it 'leaves the price alone when the destination is the home country' do
    expect(gross_for(germany)).to eq(100.00)
  end

  it 'restates for a destination with its own rate, preserving the net' do
    create(:tax_rate, name: 'FR 20% incl', amount: 0.20, tax_category: category,
                      country_iso: france&.iso, included_in_price: true, store: store)

    # net 100 / 1.19 = 84.0336, grossed by 1.20
    expect(gross_for(france)).to eq(100.84)
  end

  it 'charges the net where the destination levies nothing — a zero-rated export' do
    expect(gross_for(japan)).to eq(84.03)
  end

  # The rate table is the whole truth only for the built-in engine. Elsewhere an
  # absent row means "computed by something that keeps no rows here", not "no tax
  # due", so deducting the home VAT would turn every foreign sale into an export.
  context 'when the market is on an external tax provider' do
    let(:external_market) do
      stub_const('SpecExternalTaxProvider', Class.new(Spree::TaxProvider::Base) do
        def estimate(*); end
      end)
      # Market validates tax_provider against the registry.
      Spree.tax_providers << SpecExternalTaxProvider

      create(:market, store: store, name: "External #{Time.current.to_f}", currency: 'USD',
                      default_locale: 'en', tax_provider: 'SpecExternalTaxProvider')
    end

    after { Spree.tax_providers.delete(SpecExternalTaxProvider) if defined?(SpecExternalTaxProvider) }

    it 'does not restate at all' do
      create(:tax_rate, name: 'FR 20% incl', amount: 0.20, tax_category: category,
                        country_iso: france&.iso, included_in_price: true, store: store)

      expect(gross_for(france, market: external_market)).to eq(100.00)
    end

    it 'does not turn a rate-less destination into an export' do
      expect(gross_for(japan, market: external_market)).to eq(100.00)
    end
  end

  # The provider estimates against tax_country, which falls back to the market's
  # own country, so a cart with no address is still taxed for its destination. The
  # price has to follow, or the merchant absorbs the rate difference silently.
  describe 'a cart with no shipping address yet' do
    let(:french_market) do
      create(:market, store: store, name: "France #{Time.current.to_f}", currency: 'USD',
                      default_locale: 'en', countries: [france])
    end

    before do
      create(:tax_rate, name: 'FR 20% incl', amount: 0.20, tax_category: category,
                        country_iso: france&.iso, included_in_price: true, store: store)
    end

    it 'restates from the market country, keeping the net intact' do
      cart = create(:cart, store: store, market: french_market, currency: 'USD')
      Spree::Carts::AddItem.call(cart: cart, variant: variant, quantity: 1)

      line_item = cart.line_items.reload.first
      expect(cart.tax_address).to be_nil
      expect(line_item.price).to eq(100.84)
      expect(line_item.pre_tax_amount).to be_within(0.01).of(84.03)
    end
  end

  describe 'a price the merchant set for the destination' do
    let(:french_market) do
      create(:market, store: store, name: "France #{Time.current.to_f}", currency: 'USD',
                      default_locale: 'en', countries: [france])
    end

    let(:price_list) do
      create(:price_list, store: store).tap do |list|
        list.price_rules.create!(type: 'Spree::PriceRules::MarketRule',
                                 preferences: { market_ids: [french_market.id] })
      end
    end

    let(:list_price) do
      create(:price, variant: variant, currency: 'USD', amount: 99, price_list: price_list)
    end

    before do
      create(:tax_rate, name: 'FR 20% incl', amount: 0.20, tax_category: category,
                        country_iso: france&.iso, included_in_price: true, store: store)
    end

    it 'is charged exactly as entered' do
      expect(list_price.price_including_vat_for(country: france, market: french_market)).to eq(99.00)
    end

    it 'would otherwise have been restated' do
      # Same figure on a list with no geographic rule: 99 / 1.19 * 1.20 = 99.83.
      plain_list = create(:price_list, store: store)
      plain_list.price_rules.create!(type: 'Spree::PriceRules::VolumeRule',
                                     preferences: { min_quantity: 1 })
      volume_price = create(:price, variant: variant, currency: 'USD', amount: 99,
                                   price_list: plain_list)

      expect(volume_price.price_including_vat_for(country: france, market: french_market)).to eq(99.83)
    end
  end
  describe 'geographic rules that do not actually narrow' do
    let(:french_market) do
      create(:market, store: store, name: "France #{Time.current.to_f}", currency: 'USD',
                      default_locale: 'en', countries: [france])
    end

    before do
      create(:tax_rate, name: 'FR 20% incl', amount: 0.20, tax_category: category,
                        country_iso: france&.iso, included_in_price: true, store: store)
    end

    # A market rule with nothing selected matches everyone, which is the state the
    # admin creates it in — it must not switch restatement off for the whole list.
    it 'still restates when the market rule names no markets' do
      list = create(:price_list, store: store)
      list.price_rules.create!(type: 'Spree::PriceRules::MarketRule', preferences: { market_ids: [] })
      price = create(:price, variant: variant, currency: 'USD', amount: 95, price_list: list)

      expect(price.final_for_destination?).to be(false)
      expect(price.price_including_vat_for(country: france, market: french_market)).to eq(95.80)
    end

    # Under 'any' the list can win on the volume rule alone, so the buyer's
    # geography is not necessarily why this price applied.
    it "still restates a mixed list under the 'any' match policy" do
      list = create(:price_list, store: store, match_policy: 'any')
      list.price_rules.create!(type: 'Spree::PriceRules::MarketRule',
                               preferences: { market_ids: [french_market.id] })
      list.price_rules.create!(type: 'Spree::PriceRules::VolumeRule', preferences: { min_quantity: 1 })
      price = create(:price, variant: variant, currency: 'USD', amount: 90, price_list: list)

      expect(price.final_for_destination?).to be(false)
      expect(price.price_including_vat_for(country: france, market: french_market)).to eq(90.76)
    end

    it "treats a mixed list under 'all' as final, since every rule matched" do
      list = create(:price_list, store: store, match_policy: 'all')
      list.price_rules.create!(type: 'Spree::PriceRules::MarketRule',
                               preferences: { market_ids: [french_market.id] })
      list.price_rules.create!(type: 'Spree::PriceRules::VolumeRule', preferences: { min_quantity: 1 })
      price = create(:price, variant: variant, currency: 'USD', amount: 90, price_list: list)

      expect(price.final_for_destination?).to be(true)
      expect(price.price_including_vat_for(country: france, market: french_market)).to eq(90.00)
    end

    it 'applies the same rule to the compare-at price' do
      list = create(:price_list, store: store)
      list.price_rules.create!(type: 'Spree::PriceRules::MarketRule',
                               preferences: { market_ids: [french_market.id] })
      price = create(:price, variant: variant, currency: 'USD', amount: 90,
                            compare_at_amount: 120, price_list: list)

      expect(price.compare_at_price_including_vat_for(country: france, market: french_market)).to eq(120.00)
    end
  end
end
