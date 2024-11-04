require 'spec_helper'

RSpec.describe Spree::Products::Duplicator do
  subject(:duplicate) { described_class.call(product: product) }

  let(:store) { create(:store) }

  let!(:product_property) { create(:product_property, product: product) }
  let!(:product) { create(:product, stores: [store], tag_list: ['tag1', 'tag2']) }

  let(:filepath) { File.expand_path('../../../fixtures/thinking-cat.jpg', __dir__) }
  let(:master_image_params) do
    {
      viewable_id: product.master.id,
      viewable_type: 'Spree::Variant',
      alt: 'position 1',
      position: 1
    }
  end

  before do
    file = File.open(filepath)
    new_image = Spree::Image.new(master_image_params)
    new_image.attachment.attach(io: file, filename: File.basename(file))
    new_image.save!
  end

  it { is_expected.to be_success }

  it 'duplicates the product' do
    expect { duplicate }.to change { Spree::Product.count }.by(1)
  end

  it 'duplicates already duplicated product' do
    Timecop.scale(3600)
    expect { 3.times { described_class.call(product: product) } }.to change { Spree::Product.count }.by(3)
    Timecop.return
  end

  describe 'image duplication' do
    it 'clones images by default' do
      expect { duplicate }.to change { Spree::Image.count }.by(1)
    end

    context 'when excluding images from cloning' do
      subject(:duplicate) { described_class.call(product: product, include_images: false) }

      it 'doesn\'t clone images' do
        expect { duplicate }.not_to change(Spree::Image, :count)
      end
    end
  end

  describe 'product attributes' do
    let!(:new_product) { duplicate.value }

    it 'sets an unique name' do
      expect(new_product.name).to eql "COPY OF #{product.name}"
    end

    it 'sets an unique sku' do
      expect(new_product.sku).to include 'COPY OF SKU'
    end

    it 'copies the properties' do
      expect(new_product.product_properties.count).to eq 1
      expect(new_product.product_properties.first.property.name).to eql product_property.property.name
    end

    it 'copies tags' do
      expect(new_product.tag_list).to eq(['tag1', 'tag2'])
    end
  end

  describe 'product prices' do
    let(:new_product) { duplicate.value }

    before do
      product.master.prices.destroy_all
      product.master.prices = [
        create(:price, amount: 10.99, compare_at_amount: 11.99, currency: 'USD'),
        create(:price, amount: 8.99, compare_at_amount: 9.99, currency: 'GBP')
      ]
    end

    it 'clones prices' do
      expect(duplicate).to be_success

      usd_price = new_product.master.price_in('USD')
      expect(usd_price.amount).to eq(10.99)
      expect(usd_price.compare_at_amount).to eq(11.99)

      gbp_price = new_product.master.price_in('GBP')
      expect(gbp_price.amount).to eq(8.99)
      expect(gbp_price.compare_at_amount).to eq(9.99)
    end
  end

  describe 'stores' do
    let!(:new_product) { duplicate.value }

    it { expect(new_product.stores).to eq [store] }
  end

  context 'with variants' do
    let(:option_type) { create(:option_type, name: 'MyOptionType') }
    let(:option_value1) { create(:option_value, name: 'OptionValue1', option_type: option_type) }
    let(:option_value2) { create(:option_value, name: 'OptionValue2', option_type: option_type) }

    let!(:variant1) { create(:variant, product: product, price: 24.99, compare_at_price: 25.99, option_values: [option_value1]) }
    let!(:variant2) { create(:variant, product: product, price: 29.99, compare_at_price: 30.99, option_values: [option_value2]) }

    let(:new_product) { duplicate.value }

    before do
      product.master.update!(compare_at_price: 20.99)
    end

    it 'duplicates the variants' do
      # will change the count by 3, since there will be a master variant as well
      expect { duplicate }.to change { Spree::Variant.count }.by(3)
    end

    it 'doesn\'t duplicate the option values' do
      expect { duplicate }.to change { Spree::OptionValue.count }.by(0)
    end

    describe 'image duplication' do
      let(:variant1_image_params) do
        {
          viewable_id: variant1.id,
          viewable_type: 'Spree::Variant',
          alt: 'position 1',
          position: 1
        }
      end

      let(:variant2_image_params) do
        {
          viewable_id: variant2.id,
          viewable_type: 'Spree::Variant',
          alt: 'position 2',
          position: 2
        }
      end

      before do
        file = File.open(filepath)
        variant1_image = Spree::Image.new(variant1_image_params)
        variant1_image.attachment.attach(io: file, filename: File.basename(file))
        variant1_image.save!

        file = File.open(filepath)
        variant2_image = Spree::Image.new(variant2_image_params)
        variant2_image.attachment.attach(io: file, filename: File.basename(file))
        variant2_image.save!
      end

      it 'clones images by default' do
        expect { duplicate }.to change(Spree::Image, :count).by(3)
      end

      context 'when excluding images from cloning' do
        subject(:duplicate) { described_class.call(product: product, include_images: false) }

        it 'doesn\'t clone images' do
          expect { duplicate }.not_to change(Spree::Image, :count)
        end
      end
    end

    describe 'variant prices' do
      let(:new_product) { duplicate.value }

      before do
        variant1.prices.destroy_all
        variant1.prices = [
          create(:price, amount: 14.99, compare_at_amount: 15.99, currency: 'USD'),
          create(:price, amount: 12.99, compare_at_amount: 13.99, currency: 'GBP')
        ]

        variant2.prices.destroy_all
        variant2.prices = [
          create(:price, amount: 15.99, compare_at_amount: 16.99, currency: 'USD'),
          create(:price, amount: 13.99, compare_at_amount: 14.99, currency: 'GBP')
        ]
      end

      it 'clones prices' do
        expect(duplicate).to be_success

        variant1_usd_price = variant1.price_in('USD')
        expect(variant1_usd_price.amount).to eq(14.99)
        expect(variant1_usd_price.compare_at_amount).to eq(15.99)

        variant1_gbp_price = variant1.price_in('GBP')
        expect(variant1_gbp_price.amount).to eq(12.99)
        expect(variant1_gbp_price.compare_at_amount).to eq(13.99)

        variant2_usd_price = variant2.price_in('USD')
        expect(variant2_usd_price.amount).to eq(15.99)
        expect(variant2_usd_price.compare_at_amount).to eq(16.99)

        variant2_gbp_price = variant2.price_in('GBP')
        expect(variant2_gbp_price.amount).to eq(13.99)
        expect(variant2_gbp_price.compare_at_amount).to eq(14.99)
      end
    end
  end
end
