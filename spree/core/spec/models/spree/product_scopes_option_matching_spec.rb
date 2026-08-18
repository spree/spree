require 'spec_helper'

# "Blue and XL" has to mean a product that sells a blue XL, not one that sells
# a blue small beside a red XL. This was already wrong before sellers shared a
# catalog; sharing one only makes the wrong answer more common.
describe Spree::Product, '.with_option_value_ids', type: :model do
  let(:store) { @default_store }
  let(:color) { create(:option_type, name: 'shirt-color', presentation: 'Color') }
  let(:size) { create(:option_type, name: 'shirt-size', presentation: 'Size') }

  let(:blue) { create(:option_value, option_type: color, name: 'blue', presentation: 'Blue') }
  let(:red) { create(:option_value, option_type: color, name: 'red', presentation: 'Red') }
  let(:small) { create(:option_value, option_type: size, name: 'small', presentation: 'S') }
  let(:xl) { create(:option_value, option_type: size, name: 'xl', presentation: 'XL') }

  let(:product) { create(:product, store: store) }

  before { product.variants.destroy_all }

  it 'matches a product that sells one variant carrying both values' do
    create(:variant, product: product, option_values: [blue, xl])

    expect(described_class.with_option_value_ids(blue.id, xl.id)).to include(product)
  end

  it 'does not match a product whose values live on different variants' do
    create(:variant, product: product, option_values: [blue, small])
    create(:variant, product: product, option_values: [red, xl])

    expect(described_class.with_option_value_ids(blue.id, xl.id)).not_to include(product)
  end

  it 'still ORs within one axis' do
    create(:variant, product: product, option_values: [red, xl])

    expect(described_class.with_option_value_ids(blue.id, red.id)).to include(product)
  end

  it 'ORs within an axis and ANDs across them, on one variant' do
    create(:variant, product: product, option_values: [red, xl])

    expect(described_class.with_option_value_ids(blue.id, red.id, xl.id)).to include(product)
    expect(described_class.with_option_value_ids(blue.id, red.id, small.id)).not_to include(product)
  end

  # Every pair holding somewhere is not one variant holding them all — the
  # case a pairwise encoding gets wrong, and the reason the search providers
  # have to answer this identically.
  context 'with three option types' do
    let(:condition) { create(:option_type, name: 'shirt-condition', presentation: 'Condition') }
    let(:used) { create(:option_value, option_type: condition, name: 'used', presentation: 'Used') }
    let(:brand_new) { create(:option_value, option_type: condition, name: 'new', presentation: 'New') }

    before do
      create(:variant, product: product, option_values: [blue, xl, used])
      create(:variant, product: product, option_values: [blue, small, brand_new])
      create(:variant, product: product, option_values: [red, xl, brand_new])
    end

    it 'rejects a product whose three values only hold pairwise' do
      expect(described_class.with_option_value_ids(blue.id, xl.id, brand_new.id)).not_to include(product)
    end

    it 'matches when one variant carries all three' do
      expect(described_class.with_option_value_ids(blue.id, xl.id, used.id)).to include(product)
    end
  end

  it 'matches on a single value' do
    create(:variant, product: product, option_values: [blue, small])

    expect(described_class.with_option_value_ids(blue.id)).to include(product)
    expect(described_class.with_option_value_ids(red.id)).not_to include(product)
  end

  it 'accepts prefixed ids' do
    create(:variant, product: product, option_values: [blue, xl])

    expect(described_class.with_option_value_ids(blue.prefixed_id, xl.prefixed_id)).to include(product)
  end

  it 'ignores a deleted variant that would otherwise satisfy the filter' do
    variant = create(:variant, product: product, option_values: [blue, xl])
    variant.destroy

    expect(described_class.with_option_value_ids(blue.id, xl.id)).not_to include(product)
  end

  context 'when two sellers list variants on one product' do
    let(:seller) { create(:seller, :approved, store: store) }

    it 'does not credit one seller\'s colour to another seller\'s size' do
      create(:variant, product: product, option_values: [blue, small])
      create(:variant, product: product, seller: seller, option_values: [red, xl])

      expect(described_class.with_option_value_ids(blue.id, xl.id)).not_to include(product)
    end
  end
end
