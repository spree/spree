require 'spec_helper'

describe Spree::BaseHelper, type: :helper do
  include Spree::BaseHelper

  let(:current_store) { create :store }

  context 'available_countries' do
    let(:country) { create(:country) }

    before do
      create_list(:country, 3)
    end

    context 'with no checkout zone defined' do
      before do
        Spree::Config[:checkout_zone] = nil
      end

      it 'return complete list of countries' do
        expect(available_countries.count).to eq(Spree::Country.count)
      end
    end

    context 'with a checkout zone defined' do
      context 'checkout zone is of type country' do
        before do
          @country_zone = create(:zone, name: 'CountryZone')
          @country_zone.members.create(zoneable: country)
          Spree::Config[:checkout_zone] = @country_zone.name
        end

        it 'return only the countries defined by the checkout zone' do
          expect(available_countries).to eq([country])
        end
      end

      context 'checkout zone is of type state' do
        before do
          state_zone = create(:zone, name: 'StateZone')
          state = create(:state, country: country)
          state_zone.members.create(zoneable: state)
          Spree::Config[:checkout_zone] = state_zone.name
        end

        it 'return complete list of countries' do
          expect(available_countries.count).to eq(Spree::Country.count)
        end
      end
    end
  end

  # Regression test for #1436
  context 'defining custom image helpers' do
    let(:product) { mock_model(Spree::Product, images: [], variant_images: []) }

    before do
      Spree::Image.class_eval do
        styles[:very_strange] = '1x1'
        styles.merge!(foobar: '2x2')
      end
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

  # Regression test for #2396
  context 'meta_data_tags' do
    it 'truncates a product description to 160 characters' do
      # Because the controller_name method returns "test"
      # controller_name is used by this method to infer what it is supposed
      # to be generating meta_data_tags for
      text = FFaker::Lorem.paragraphs(2).join(' ')
      @test = Spree::Product.new(description: text)
      tags = Nokogiri::HTML.parse(meta_data_tags)
      content = tags.css('meta[name=description]').first['content']
      assert content.length <= 160, 'content length is not truncated to 160 characters'
    end
  end

  # Regression test for #5384

  context 'pretty_time' do
    it 'prints in a format' do
      expect(pretty_time(Time.new(2012, 5, 6, 13, 33))).to eq 'May 06, 2012  1:33 PM'
    end
  end

  describe '#display_price' do
    let!(:product) { create(:product) }
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

  describe '#default_image_for_product_or_variant' do
    let(:product) { build :product }
    let(:variant) { build :variant, product: product }

    subject(:default_image) { default_image_for_product_or_variant(product_or_variant) }

    context 'when Product passed' do
      let(:product_or_variant) { product }

      it { is_expected.to eq(nil) }

      context 'and Variant has images' do
        let!(:image_1) { create :image, viewable: variant }
        let!(:image_2) { create :image, viewable: variant }

        it { is_expected.to eq(image_1) }
      end

      context 'and master Variant has images' do
        let!(:image_1) { create :image, viewable: product.master }
        let!(:image_2) { create :image, viewable: product.master }

        it { is_expected.to eq(image_1) }
      end
    end

    context 'when Variant passed' do
      let(:product_or_variant) { variant }

      it { is_expected.to eq(nil) }

      context 'and Variant has images' do
        let!(:image_1) { create :image, viewable: variant }
        let!(:image_2) { create :image, viewable: variant }

        it { is_expected.to eq(image_1) }
      end

      context 'and another Variant of the Product has images' do
        let(:variant_2) { build :variant, product: product }
        let!(:image_1) { create :image, viewable: variant_2 }
        let!(:image_2) { create :image, viewable: variant_2 }

        it { is_expected.to eq(image_1) }
      end
    end
  end

<<<<<<< HEAD
  describe '#meta_image_data_tag' do
    context 'when meta_image_url_path is present' do
      it 'returns meta tag' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_image_url_path).and_return('image_url')
=======
  describe '#meta_image_url_path' do
    let!(:product) { build :product }
    before { allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product) }
>>>>>>> Adds extra product meta tags

    context 'when product has no images attached' do
      it 'returns spree logo url' do
        expect(meta_image_url_path).to eq asset_path(Spree::Config[:logo])
      end
    end

<<<<<<< HEAD
    context 'when meta_image_url_path is absent' do
      it 'returns meta tag' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_image_url_path).and_return(nil)
=======
    context 'when product has an image attached' do
      let!(:image) { create :image, viewable: product.master }
>>>>>>> Adds extra product meta tags

      it 'returns main image url path' do
        expect(meta_image_url_path).to eq asset_path(main_app.url_for(image.attachment))
      end
    end
  end

<<<<<<< HEAD
  describe '#meta_image_url_path' do
    context 'when object is not a product' do
      let!(:taxon) { build :taxon }
=======
  describe '#meta_product_image_data_tag' do
    context 'when image url path is present' do
      it 'returns meta product image tag' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_image_url_path).and_return('image_url')

        expect(meta_product_image_data_tag).to eq "<meta property=\"og:image\" content=\"image_url\" />"
      end
    end
>>>>>>> Adds extra product meta tags

    context 'when image url path is absent' do
      it 'returns nil' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_image_url_path).and_return(nil)

<<<<<<< HEAD
        expect(meta_image_url_path).to eq nil
=======
        expect(meta_product_data_tags).to eq nil
>>>>>>> Adds extra product meta tags
      end
    end
  end

  describe '#meta_product_url_path' do
    context 'when current_store url and object slug are present' do
      let!(:current_store) { build(:store, url: 'example.com') }
      let!(:product)       { build(:product, slug: 'shirt') }

      it 'returns full product url' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product)

        expect(meta_product_url_path).to eq "https://#{current_store.url}/products/#{product.slug}"
      end
    end

    context 'when current_store url and object slug are absent' do
      it 'returns partial of product url' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(nil)

        expect(meta_product_url_path).to eq nil
      end
    end
  end

  describe '#meta_product_url_tag' do
    context 'when current_store url and object slug are present' do
      it 'returns product url tag' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_url_path).and_return("https://example.com/products/shirt")

        expect(meta_product_url_tag).to eq(
          "<meta property=\"og:url\" content=\"https://example.com/products/shirt\" />"
        )
      end
    end

    context 'when current_store url and object slug are absent' do
      it 'returns nil' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(nil)

        expect(meta_product_url_tag).to eq nil
      end
    end
  end

  describe '#meta_types' do
    context 'when product is present' do
      context 'that has no taxons' do
        let!(:product) { build(:product) }

        it 'returns an empty string' do
          allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product)

          expect(meta_types).to eq ''
        end
      end

      context 'that has taxons' do
        let!(:taxon_1)       { build(:taxon, name: 'taxon_1') }
        let!(:taxon_2)       { build(:taxon, name: 'taxon_2') }
        let!(:product)       { build(:product, taxons: [taxon_1, taxon_2]) }

        it 'returns string of taxons names' do
          allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product)

          expect(meta_types).to eq 'taxon_1 taxon_2'
        end
      end

    end

    context 'when product is absent' do
      it 'returns an empty string' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(nil)

        expect(meta_types).to eq nil
      end
    end
  end

  describe '#meta_product_types_tag' do
    context 'when meta type is present' do
      it 'returns meta product types tag' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_types).and_return('taxon')

        expect(meta_product_types_tag).to eq "<meta property=\"og:type\" content=\"taxon\" />"
      end
    end

    context 'when meta type is absent' do
      it 'returns nil' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_types).and_return(nil)

        expect(meta_product_types_tag).to eq nil
      end
    end
  end

  describe '#meta_product_title_tag' do
    context 'when product name is present' do
      let!(:product) { build(:product, name: 'Spree Bag') }

      it 'returns meta product title tag' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product)

        expect(meta_product_title_tag).to eq "<meta property=\"og:title\" content=\"#{product.name}\" />"
      end
    end

    context 'when product name is absent' do
      it 'returns nil' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(nil)

        expect(meta_product_title_tag).to eq nil
      end
    end
  end

  describe '#meta_product_description' do
    context 'when product is present' do
      context 'with description' do
        let!(:product) { build(:product, description: 'Description') }

        it 'returns product description' do
          allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product)

          expect(meta_product_description).to eq product.description
        end
      end

<<<<<<< HEAD
      context 'and has no images attached' do
        it 'returns spree logo url' do
          expect(meta_image_url_path).to eq asset_path(Spree::Config[:logo])
=======
      context 'with meta description' do
        let!(:product) { build(:product, description: nil, meta_description: 'Meta Description') }

        it 'returns product meta description' do
          allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product)

          expect(meta_product_description).to eq product.meta_description
>>>>>>> Adds extra product meta tags
        end
      end

      context 'without meta description and description' do
        let!(:product) { build(:product, description: nil) }

<<<<<<< HEAD
        it 'returns main image url' do
          expect(meta_image_url_path).to eq asset_path(main_app.url_for(image.attachment))
=======
        it 'returns nil' do
          allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product)

          expect(meta_product_description).to eq nil
>>>>>>> Adds extra product meta tags
        end
      end
    end

    context 'when product is absent' do
      it 'returns nil' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(nil)

        expect(meta_product_description).to eq nil
      end
    end
  end

  describe '#meta_product_description_tag' do
    context 'when meta product description is present' do
      it 'returns meta product title tag' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_description).and_return('description')

        expect(meta_product_description_tag).to eq "<meta property=\"og:description\" content=\"description\" />"
      end
    end

    context 'when meta product description is absent' do
      it 'returns nil' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_description).and_return(nil)

        expect(meta_product_description_tag).to eq nil
      end
    end
  end

  describe '#meta_product_app_id_tag' do
    context 'when fb app id is present' do
      it 'returns meta product app id tag' do
        Spree::Config[:fb_app_id] = 'app_id'
        expect(meta_product_app_id_tag).to eq "<meta property=\"fb:app_id\" content=\"app_id\" />"
      end
    end

    context 'when fb app id is absent' do
      it 'returns nil' do
        expect(meta_product_app_id_tag).to eq nil
      end
    end
  end

  describe '#meta_product_data_tags' do
    context 'when object is not a product' do
      it 'returns nil' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(nil)

        expect(meta_product_data_tags).to eq nil
      end
    end

    context 'when object is a product' do
      let!(:product)         { build(:product) }
      let!(:image_tag)       { "<meta property=\"og:image\" content=\"image_url\" />" }
      let!(:url_tag)         { "<meta property=\"og:url\" content=\"https://example.com/products/spree-bag\" />" }
      let!(:type_tag)        { "<meta property=\"og:type\" content=\"taxon\" />" }
      let!(:title_tag)       { "<meta property=\"og:title\" content=\"Spree Bag\" />" }
      let!(:description_tag) { "<meta property=\"og:description\" content=\"description\" />" }
      let!(:fb_app_id_tag)   { "<meta property=\"fb:app_id\" content=\"app_id\" />" }

      it 'returns string of meta product data tags' do
        allow_any_instance_of(Spree::BaseHelper).to receive(:object).and_return(product)
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_image_data_tag).and_return(image_tag)
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_url_tag).and_return(url_tag)
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_types_tag).and_return(type_tag)
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_title_tag).and_return(title_tag)
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_description_tag).and_return(description_tag)
        allow_any_instance_of(Spree::BaseHelper).to receive(:meta_product_app_id_tag).and_return(fb_app_id_tag)

        expect(meta_product_data_tags).to eq(
          [image_tag, url_tag, type_tag, title_tag, description_tag, fb_app_id_tag].join("\n")
        )
      end
    end
  end
end
