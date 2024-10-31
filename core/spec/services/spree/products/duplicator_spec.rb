require 'spec_helper'

RSpec.describe Spree::Products::Duplicator do
  subject(:duplicate) { described_class.call(product: product) }

  let(:store) { create(:store) }

  let!(:product_property) { create(:product_property, product: product) }
  let!(:product) { create(:product, stores: [store]) }

  let(:file) { File.open(File.expand_path('../../../fixtures/thinking-cat.jpg', __dir__)) }
  let(:params) do
    {
      viewable_id: product.master.id,
      viewable_type: 'Spree::Variant',
      alt: 'position 1',
      position: 1
    }
  end

  before do
    new_image = Spree::Image.new(params)
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
  end

  describe 'stores' do
    let!(:new_product) { duplicate.value }

    it { expect(new_product.stores).to eq [store] }
  end

  context 'with variants' do
    let(:option_type) { create(:option_type, name: 'MyOptionType') }
    let(:option_value1) { create(:option_value, name: 'OptionValue1', option_type: option_type) }
    let(:option_value2) { create(:option_value, name: 'OptionValue2', option_type: option_type) }

    let!(:variant1) { create(:variant, product: product, option_values: [option_value1]) }
    let!(:variant2) { create(:variant, product: product, option_values: [option_value2]) }

    it 'duplicates the variants' do
      # will change the count by 3, since there will be a master variant as well
      expect { duplicate }.to change { Spree::Variant.count }.by(3)
    end

    it 'doesn\'t duplicate the option values' do
      expect { duplicate }.to change { Spree::OptionValue.count }.by(0)
    end
  end
end
