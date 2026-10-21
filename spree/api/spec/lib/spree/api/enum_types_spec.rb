require 'spec_helper'
require Spree::Api::Engine.root.join('lib/spree/api/enum_types').to_s

RSpec.describe Spree::Api::EnumTypes do
  def property(enum_type_name, enum)
    Typelizer::Property.new(name: :status, type: :string, enum: enum, enum_type_name: enum_type_name)
  end

  let(:monorepo_root) { Spree::Api::Engine.root.join('../..') }

  it 'matches the committed @spree/core file (run `bundle exec rake typelizer:generate` to refresh it)' do
    Rails.autoloaders.main.eager_load_dir(Spree::Api::Engine.root.join('app/serializers/spree/api/v3').to_s)

    expect(monorepo_root.join(described_class::PATH).read).to eq(described_class.new.render)
  end

  it 'writes each open list once, as values and an open type, leaving out the code lists' do
    source = described_class.new([
      property('ProductStatus', %w[draft active]),
      property('ProductStatus', %w[draft active]),
      property('CurrencyCode', %w[EUR USD]),
      property(nil, %w[a b])
    ]).render

    expect(source.scan('PRODUCT_STATUSES =').size).to eq(1)
    expect(source).to include("export const PRODUCT_STATUSES = ['draft', 'active'] as const\n")
    expect(source).to include("export type ProductStatus = (typeof PRODUCT_STATUSES)[number] | (string & {})\n")
    expect(source).not_to include('Currency')
  end

  it 'keeps a closed list closed' do
    source = described_class.new([property('SellerTransferKind', %w[earning refund_reversal])]).render

    expect(source).to include("export type SellerTransferKind = (typeof SELLER_TRANSFER_KINDS)[number]\n")
  end

  it 'joins every status list into one type of the built-in statuses' do
    source = described_class.new([property('ProductStatus', %w[draft]), property('FeeKind', %w[duty])]).render

    expect(source).to include("export type BuiltInStatus =\n  | (typeof PRODUCT_STATUSES)[number]\n")
    expect(source[/export type BuiltInStatus.*/m]).not_to include('FEE_KINDS')
  end

  it 'finds two attributes of one serializer that disagree, which Typelizer would collapse into one' do
    nested = property('ProductStatus', %w[draft])
    parent = Typelizer::Property.new(name: :product, type: :object, nested_properties: [nested])

    expect(described_class.named_properties([property('ProductStatus', %w[draft active]), parent]).size).to eq(2)
  end

  it 'refuses a list two serializers declare with different values' do
    generator = described_class.new([property('ProductStatus', %w[draft active]), property('ProductStatus', %w[draft])])

    expect { generator.render }.to raise_error(described_class::ConflictError, /ProductStatus/)
  end
end
