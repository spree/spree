require 'spec_helper'

# Regression for #15062: under eager loading the V2 Platform serializers load
# before Spree.metafields.enabled_resources is filled, miss the metafields
# relationship, and ?include=metafields 400s. The backfill re-applies the
# relationship once the list is final.
RSpec.describe Spree::Core::MetafieldsSerializerBackfill do
  let(:metafield_serializer) { double('MetafieldSerializer') }

  # A platform serializer as it comes up on an eager-loaded boot: loaded,
  # responding to the jsonapi-serializer class API, WITHOUT :metafields.
  let(:serializer) do
    Class.new do
      class << self
        def relationships_to_serialize
          @relationships_to_serialize ||= {}
        end

        def has_many_calls
          @has_many_calls ||= []
        end

        def has_many(name, **options)
          has_many_calls << [name, options]
          relationships_to_serialize[name] = options
        end
      end
    end
  end

  before do
    stub_const('Spree::Api::V2::Platform::TaxonSerializer', serializer)
    allow(Spree).to receive(:api).and_return(double(platform_metafield_serializer: metafield_serializer))
  end

  it 'adds the metafields relationship a serializer missed at class-load time' do
    described_class.call([Spree::Taxon])

    expect(serializer.has_many_calls).to contain_exactly(
      [:metafields, { serializer: metafield_serializer, record_type: :metafield, object_method_name: :metafields }]
    )
  end

  it 'is idempotent: a serializer that already has the relationship is left alone' do
    described_class.call([Spree::Taxon])
    described_class.call([Spree::Taxon])

    expect(serializer.has_many_calls.size).to eq(1)
  end

  it 'skips resources without a platform serializer or without metafields' do
    model_without_metafields = Class.new { def self.name = 'Spree::Taxon' }

    expect { described_class.call([Spree::Address, model_without_metafields]) }.not_to raise_error
    expect(serializer.has_many_calls).to be_empty
  end
end
