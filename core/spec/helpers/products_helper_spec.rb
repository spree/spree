require 'spec_helper'

module Spree
  describe ProductsHelper, type: :helper do
    include ProductsHelper

    let(:store) { Spree::Store.default }

    let(:product) { create(:product, stores: [store]) }
    let(:currency) { 'USD' }

    before do
      allow(helper).to receive(:current_currency) { currency }
    end

    context '#variant_price_diff' do
      subject { helper.variant_price(@variant) }

      let(:product_price) { 10 }
      let(:variant_price) { 10 }

      before do
        @variant = create(:variant, product: product)
        product.price = 15
        @variant.price = 10
        allow(product).to receive(:amount_in) { product_price }
        allow(@variant).to receive(:amount_in) { variant_price }
      end

      context 'when variant is same as master' do
        it { is_expected.to be_nil }
      end

      context 'when the master has no price' do
        let(:product_price) { nil }

        it { is_expected.to be_nil }
      end

      context 'when currency is default' do
        context 'when variant is more than master' do
          let(:variant_price) { 15 }

          it { is_expected.to eq('(Add: $5.00)') }
          # Regression test for #2737
          it { is_expected.to be_html_safe }
        end

        context 'when variant is less than master' do
          let(:product_price) { 15 }

          it { is_expected.to eq('(Subtract: $5.00)') }
        end
      end

      context 'when currency is JPY' do
        let(:variant_price) { 100 }
        let(:product_price) { 100 }
        let(:currency) { 'JPY' }

        context 'when variant is more than master' do
          let(:variant_price) { 150 }

          it { is_expected.to eq('(Add: &#x00A5;50)') }
        end

        context 'when variant is less than master' do
          let(:product_price) { 150 }

          it { is_expected.to eq('(Subtract: &#x00A5;50)') }
        end
      end
    end

    context '#variant_price_full' do
      before do
        Spree::Config[:show_variant_full_price] = true
        @variant1 = create(:variant, product: product)
        @variant2 = create(:variant, product: product)
      end

      context 'when currency is default' do
        it 'returns the variant price if the price is different than master' do
          product.price = 10
          @variant1.price = 15
          @variant2.price = 20
          expect(helper.variant_price(@variant1)).to eq('$15.00')
          expect(helper.variant_price(@variant2)).to eq('$20.00')
        end
      end

      context 'when currency is JPY' do
        let(:currency) { 'JPY' }

        before do
          product.variants.active.each do |variant|
            variant.prices.each do |price|
              price.currency = currency
              price.save!
            end
          end
        end

        it 'returns the variant price if the price is different than master' do
          product.price = 100
          @variant1.price = 150
          expect(helper.variant_price(@variant1)).to eq('&#x00A5;150')
        end
      end

      it 'is nil when all variant prices are equal' do
        product.price = 10
        @variant1.default_price.update_column(:amount, 10)
        @variant2.default_price.update_column(:amount, 10)
        expect(helper.variant_price(@variant1)).to be_nil
        expect(helper.variant_price(@variant2)).to be_nil
      end
    end

    shared_examples_for 'line item descriptions' do
      context 'variant has a blank description' do
        let(:description) { nil }

        it { is_expected.to eq(Spree.t(:product_has_no_description)) }
      end

      context 'variant has a description' do
        let(:description) { 'test_desc' }

        it { is_expected.to eq(description) }
      end

      context 'description has nonbreaking spaces' do
        let(:description) { 'test&nbsp;desc' }

        it { is_expected.to eq('test desc') }
      end

      context 'description has line endings' do
        let(:description) { "test\n\r\ndesc" }

        it { is_expected.to eq('test desc') }
      end
    end

    context '#line_item_description_text' do
      subject { line_item_description_text description }

      it_behaves_like 'line item descriptions'
    end

    context '#cache_key_for_products' do
      subject { helper.cache_key_for_products(products) }

      let(:zone) { Spree::Zone.new }
      let(:price_options) { { tax_zone: zone } }
      let!(:products) { create_list(:product, 5, stores: [store]) }
      let(:product_ids) { products.map(&:id).join('-') }
      let(:taxon) { create(:taxon) }

      before do
        allow(helper).to receive(:params).and_return(page: 10)
        allow(helper).to receive(:current_price_options) { price_options }

        allow(products).to receive(:except).with(:group, :order).and_return(products)
      end

      context 'when there is a maximum updated date' do
        let(:updated_at) { Date.new(2011, 12, 13) }

        before do
          allow(products).to receive(:maximum).with(:updated_at) { updated_at }
        end

        it { is_expected.to eq("en/USD/spree/zones/new/spree/products/#{product_ids}-10--20111213-") }
      end

      context 'when there is no considered maximum updated date' do
        let(:today) { Date.new(2013, 12, 11) }

        before do
          allow(products).to receive(:maximum).with(:updated_at).and_return(nil)
          allow(Date).to receive(:today) { today }
        end

        it { is_expected.to eq("en/USD/spree/zones/new/spree/products/#{product_ids}-10--20131211-") }
      end

      context 'with Taxon ID present' do
        let(:updated_at) { Date.new(2011, 12, 13) }

        before do
          @taxon = taxon
          allow(products).to receive(:maximum).with(:updated_at) { updated_at }
        end

        it { is_expected.to eq("en/USD/spree/zones/new/spree/products/#{product_ids}-10--20111213-#{taxon.id}") }
      end

      context 'with `additional_cache_key` passed' do
        subject { helper.cache_key_for_products(products, 'json-ld') }

        let(:updated_at) { Date.new(2011, 12, 13) }

        before do
          @taxon = taxon
          allow(products).to receive(:maximum).with(:updated_at) { updated_at }
        end

        it { is_expected.to eq("en/USD/spree/zones/new/spree/products/#{product_ids}-10--20111213-#{taxon.id}/json-ld") }
      end
    end

    context '#cache_key_for_product' do
      subject(:cache_key) { helper.cache_key_for_product(product) }

      let(:product) { store.products.new }
      let(:price_options) { { tax_zone: zone } }

      before do
        allow(helper).to receive(:current_price_options) { price_options }
      end

      context 'when there is a current tax zone' do
        let(:zone) { Spree::Zone.new }

        it 'includes the current_tax_zone' do
          expect(subject).to eq('en/USD/spree/zones/new/spree/products/new/')
        end
      end

      context 'when there is no current tax zone' do
        let(:zone) { nil }

        it { is_expected.to eq('en/USD/spree/products/new/') }
      end

      context 'when current_price_options includes nil values' do
        let(:price_options) do
          {
            a: nil,
            b: Spree::Zone.new
          }
        end

        it 'does not include nil values' do
          expect(cache_key).to eq('en/USD/spree/zones/new/spree/products/new/')
        end
      end

      context 'when current_price_options includes values that do not implement cache_key' do
        let(:price_options) do
          {
            a: true,
            b: Spree::Zone.new
          }
        end

        it 'includes string representations of these values' do
          expect(cache_key).to eq('en/USD/true/spree/zones/new/spree/products/new/')
        end
      end

      context 'when keys in the options hash are inserted in non-alphabetical order' do
        let(:price_options) do
          {
            b: Spree::Zone.new,
            a: true
          }
        end

        it 'the values are nevertheless returned in alphabetical order of their keys' do
          expect(cache_key).to eq('en/USD/true/spree/zones/new/spree/products/new/')
        end
      end

      context 'given possible promotions' do
        let(:zone) { nil }
        let(:promotion) { create :promotion }
        let(:promotion_2) { create :promotion }

        before do
          allow(product).to receive(:possible_promotions).and_return([promotion, promotion_2])
        end

        it { is_expected.to eq("en/USD/spree/products/new/#{promotion.cache_key}/#{promotion_2.cache_key}") }
      end
    end
  end
end
