require 'spec_helper'

describe Spree::BaseHelper, type: :helper do
  include described_class

  let(:current_store) { create(:store) }

  before do
    allow(controller).to receive(:controller_name).and_return('test')
    allow(Rails.application.routes).to receive(:default_url_options).and_return(protocol: 'http', port: nil)
  end

  context 'available_countries' do
    before do
      create_list(:country, 3)
    end

    context 'with markets' do
      let!(:country) { create(:country) }

      before do
        create(:market, store: current_store, countries: [country], currency: 'USD', default: true)
      end

      it 'returns only the countries from markets' do
        expect(available_countries).to eq([country])
      end
    end

    context 'without markets' do
      it 'returns complete list of countries' do
        expect(available_countries).to contain_exactly(*Spree::Country.all)
      end
    end
  end

  describe '#spree_storefront_resource_url' do
    let!(:store) { @default_store }
    let!(:taxon) { create(:taxon) }
    let!(:product) { create(:product) }

    before do
      allow(helper).to receive(:frontend_available?).and_return(false)
      allow(helper).to receive(:current_store).and_return(store)
      allow(helper).to receive(:locale_param)
    end

    context 'for Product URL' do
      it { expect(helper.spree_storefront_resource_url(product)).to eq("http://www.example.com/products/#{product.slug}") }

      context 'when a locale is passed' do
        before do
          allow(helper).to receive(:current_store).and_return(store)
        end

        it { expect(helper.spree_storefront_resource_url(product, locale: :de)).to eq("http://www.example.com/de/products/#{product.slug}") }
      end

      context 'when locale_param is present' do
        before do
          allow(helper).to receive(:locale_param).and_return(:fr)
        end

        it { expect(helper.spree_storefront_resource_url(product)).to eq("http://www.example.com/fr/products/#{product.slug}") }
      end

      context 'when preview_id is not present' do
        it 'returns the product url' do
          expect(spree_storefront_resource_url(product)).to eq("http://#{current_store.url}/products/#{product.slug}")
        end
      end

      context 'when preview_id is present' do
        it 'returns the product preview url' do
          expect(spree_storefront_resource_url(product, preview_id: product.id)).to eq("http://#{current_store.url}/products/#{product.slug}?preview_id=#{product.id}")
        end
      end

      context 'for product with relative option' do
        it 'returns the product url' do
          expect(spree_storefront_resource_url(product, relative: true)).to eq("/products/#{product.slug}")
        end
      end
    end

    context 'for Taxon URL' do
      it { expect(helper.spree_storefront_resource_url(taxon)).to eq("http://www.example.com/t/#{taxon.permalink}") }

      context 'when a locale is passed' do
        it { expect(helper.spree_storefront_resource_url(taxon, locale: :de)).to eq("http://www.example.com/de/t/#{taxon.permalink}") }
      end

      context 'when locale_param is present' do
        before do
          allow(helper).to receive(:locale_param).and_return(:fr)
        end

        it { expect(helper.spree_storefront_resource_url(taxon)).to eq("http://www.example.com/fr/t/#{taxon.permalink}") }
      end
    end
  end

  # Regression test for #1436
  context 'defining custom image helpers' do
    let(:product) { build(:product) }

    before do
      module ImageDecorator
        module ClassMethods
          def styles
            super.merge(
              very_strange: '1x1',
              foobar: '2x2'
            )
          end
        end

        def self.prepended(base)
          base.singleton_class.prepend ClassMethods
        end
      end

      Spree::Image.prepend(ImageDecorator)
    end

    it 'does not raise errors when style exists' do
      expect { very_strange_image(product) }.not_to raise_error
    end

    it 'raises NoMethodError when style is not exists' do
      expect { another_strange_image(product) }.to raise_error(NoMethodError)
    end

    it 'does not raise errors when helper method called' do
      expect { foobar_image(product) }.not_to raise_error
    end

    it 'raises NoMethodError when statement with name equal to style name called' do
      expect { foobar(product) }.to raise_error(NoMethodError)
    end
  end

  context 'link_to_tracking' do
    it 'returns tracking link if available' do
      a = link_to_tracking_html(shipping_method: true, tracking: '123', tracking_url: 'http://g.c/?t=123').css('a')

      expect(a.text).to eq '123'
      expect(a.attr('href').value).to eq 'http://g.c/?t=123'
    end

    it 'returns tracking without link if link unavailable' do
      html = link_to_tracking_html(shipping_method: true, tracking: '123', tracking_url: nil)
      expect(html.css('span').text).to eq '123'
    end

    it 'returns nothing when no shipping method' do
      html = link_to_tracking_html(shipping_method: nil, tracking: '123')
      expect(html.css('span').text).to eq ''
    end

    it 'returns nothing when no tracking' do
      html = link_to_tracking_html(tracking: nil)
      expect(html.css('span').text).to eq ''
    end

    def link_to_tracking_html(options = {})
      node = link_to_tracking(double(:shipment, options))
      Nokogiri::HTML(node.to_s)
    end
  end

  context 'spree_base_cache_key' do
    let(:current_currency) { 'USD' }

    context 'when try_spree_current_user defined' do
      before do
        allow(I18n).to receive(:locale).and_return(I18n.default_locale)
        allow_any_instance_of(described_class).to receive(:try_spree_current_user).and_return(user)
      end

      context 'when admin user' do
        let!(:user) { create(:admin_user) }

        it 'returns base cache key' do
          expect(spree_base_cache_key).to eq [:en, 'USD', true, user.role_users.cache_key_with_version]
        end
      end

      context 'when user without admin role' do
        let!(:user) { create(:user) }

        it 'returns base cache key' do
          expect(spree_base_cache_key).to eq [:en, 'USD', true, user.role_users.cache_key_with_version]
        end
      end

      context 'when spree_current_user is nil' do
        let!(:user) { nil }

        it 'returns base cache key' do
          expect(spree_base_cache_key).to eq [:en, 'USD', false, false]
        end
      end
    end

    context 'when try_spree_current_user is undefined' do
      let(:current_currency) { 'USD' }

      before do
        allow(I18n).to receive(:locale).and_return(I18n.default_locale)
      end

      it 'returns base cache key' do
        expect(spree_base_cache_key).to eq [:en, 'USD']
      end
    end
  end

  # Regression test for #5384

  context 'pretty_time' do
    it 'prints in a format' do
      time = Time.new(2012, 5, 6, 13, 33)
      expect(pretty_time(time)).to eq "May 06, 2012  1:33 PM #{time.zone}"
    end

    it 'return empty string when nil is supplied' do
      expect(pretty_time(nil)).to eq ''
    end
  end

  context 'pretty_date' do
    it 'prints in a format' do
      expect(pretty_date(Time.new(2012, 5, 6, 13, 33))).to eq 'May 06, 2012'
    end

    it 'return empty string when nil is supplied' do
      expect(pretty_date(nil)).to eq ''
    end
  end

  describe '#display_price' do
    let!(:product) { create(:product, stores: [current_store]) }
    let(:current_currency) { 'USD' }
    let(:current_price_options) { { tax_zone: current_tax_zone } }

    context 'when there is no current order' do
      let (:current_tax_zone) { nil }

      it 'returns the price including default vat' do
        expect(display_price(product)).to eq('$19.99')
      end

      context 'with a default VAT' do
        let(:current_tax_zone) { create(:zone_with_country, default_tax: true) }
        let!(:tax_rate) do
          create :tax_rate,
                 included_in_price: true,
                 zone: current_tax_zone,
                 tax_category: product.tax_category,
                 amount: 0.2
        end

        it 'returns the price adding the VAT' do
          expect(display_price(product)).to eq('$19.99')
        end
      end
    end

    context 'with an order that has a tax zone' do
      let(:current_tax_zone) { create(:zone_with_country) }
      let(:current_order) { Spree::Order.new }
      let(:default_zone) { create(:zone_with_country, default_tax: true) }

      let!(:default_vat) do
        create :tax_rate,
               included_in_price: true,
               zone: default_zone,
               tax_category: product.tax_category,
               amount: 0.2
      end

      context 'that matches no VAT' do
        it 'returns the price excluding VAT' do
          expect(display_price(product)).to eq('$16.66')
        end
      end

      context 'that matches a VAT' do
        let!(:other_vat) do
          create :tax_rate,
                 included_in_price: true,
                 zone: current_tax_zone,
                 tax_category: product.tax_category,
                 amount: 0.4
        end

        it 'returns the price adding the VAT' do
          expect(display_price(product)).to eq('$23.32')
        end
      end
    end
  end

  describe '#spree_favicon_path' do
    context 'when a store has its own favicon' do
      let(:current_store) { create(:store, :with_favicon) }

      it do
        expect(spree_favicon_path).to end_with('thinking-cat.jpg')
        expect(URI.parse(spree_favicon_path).host).to be_present
      end
    end

    context 'when a store has no favicon' do
      it do
        expect(spree_favicon_path).to eq('favicon.ico')
      end
    end
  end
end
