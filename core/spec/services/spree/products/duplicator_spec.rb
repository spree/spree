require 'spec_helper'

RSpec.describe Spree::Products::Duplicator do
  subject(:duplicate) { described_class.call(product: product.reload) }

  let(:store) { @default_store }

  let!(:product_property) { create(:product_property, product: product) }
  let!(:product) { create(:product, stores: [store], tag_list: ['tag1', 'tag2'], status: :active) }

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

    product.master.update!(barcode: '1234567890')
    product.master.stock_items.last.update!(count_on_hand: 100, backorderable: true)
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

    it 'always sets the product as draft' do
      expect(new_product).to be_draft
    end

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

    it 'clones barcode' do
      expect(new_product.barcode).to eq('1234567890')
    end

    it 'clones backorderable and sets stock to 0' do
      expect(new_product.master).to be_backorderable
      expect(new_product.master.total_on_hand).to eq(0)
    end
  end

  describe 'product prices' do
    let(:new_product) { duplicate.value }

    before do
      product.master.set_price('USD', 10.99, 11.99)
      product.master.set_price('GBP', 8.99, 9.99)
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

    let!(:variant1) { create(:variant, product: product, option_values: [option_value1], barcode: 'v1-123') }
    let!(:variant2) { create(:variant, product: product, option_values: [option_value2], barcode: 'v2-456') }

    let(:new_product) { duplicate.value }

    before do
      variant1.stock_items.last.update!(count_on_hand: 100, backorderable: true)
      variant2.stock_items.last.update!(count_on_hand: 200, backorderable: false)
    end

    it 'duplicates the variants' do
      # will change the count by 3, since there will be a master variant as well
      expect { duplicate }.to change { Spree::Variant.count }.by(3)
    end

    it 'doesn\'t duplicate the option values' do
      expect { duplicate }.to change { Spree::OptionValue.count }.by(0)
    end

    it 'clones barcodes' do
      expect(new_product.variants.pluck(:barcode)).to contain_exactly('v1-123', 'v2-456')
    end

    it 'clones backorderable and sets stock to 0' do
      variant1_copy = new_product.variants.find_by!(barcode: 'v1-123')
      expect(variant1_copy).to be_backorderable
      expect(variant1_copy.total_on_hand).to eq(0)

      variant2_copy = new_product.variants.find_by!(barcode: 'v2-456')
      expect(variant2_copy).not_to be_backorderable
      expect(variant2_copy.total_on_hand).to eq(0)
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
        variant1.set_price('USD', 14.99, 15.99)
        variant1.set_price('GBP', 12.99, 13.99)

        variant2.set_price('USD', 15.99, 16.99)
        variant2.set_price('GBP', 13.99, 14.99)
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
