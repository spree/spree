# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::MetafieldFilterable do
  let(:store) { @default_store }

  let!(:product_1) { create(:product, name: 'Blue Shirt') }
  let!(:product_2) { create(:product, name: 'Red Pants') }
  let!(:product_3) { create(:product, name: 'Blue Jacket') }

  let!(:material) do
    create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'material')
  end
  let!(:weight) do
    create(:metafield_definition, :number_field, :sortable, namespace: 'custom', key: 'weight')
  end

  before do
    product_1.set_metafield(material, 'Wool-Blend')
    product_2.set_metafield(material, 'cotton')
    product_1.set_metafield(weight, '10')
    product_2.set_metafield(weight, '2')
    product_3.set_metafield(weight, '3.5')
  end

  def filter(filters)
    scope, remaining = Spree::Product.with_metafield_filters(filters)
    [scope.to_a, remaining]
  end

  describe '.with_metafield_filters' do
    it 'returns the untouched scope and filters when no cf_* keys are present' do
      scope, remaining = Spree::Product.with_metafield_filters({'name_cont' => 'Blue'})

      expect(scope.to_a).to match_array([product_1, product_2, product_3])
      expect(remaining).to eq('name_cont' => 'Blue')
    end

    it 'consumes cf_* keys and leaves the rest for Ransack' do
      _, remaining = filter({'cf_custom_material_eq' => 'cotton', 'name_cont' => 'Blue'})

      expect(remaining).to eq('name_cont' => 'Blue')
    end

    it 'matches substrings with cont' do
      expect(filter({'cf_custom_material_cont' => 'Wool'}).first).to contain_exactly(product_1)
    end

    # `cont` case-sensitivity is adapter-dependent (SQLite/MySQL fold ASCII,
    # PostgreSQL does not); `i_cont` must fold everywhere.
    it 'ignores case with i_cont' do
      expect(filter({'cf_custom_material_i_cont' => 'WOOL'}).first).to contain_exactly(product_1)
    end

    it 'filters text values with eq, not_eq, start and end' do
      expect(filter({'cf_custom_material_eq' => 'cotton'}).first).to contain_exactly(product_2)
      expect(filter({'cf_custom_material_not_eq' => 'cotton'}).first).to contain_exactly(product_1)
      expect(filter({'cf_custom_material_start' => 'Wool'}).first).to contain_exactly(product_1)
      expect(filter({'cf_custom_material_end' => 'Blend'}).first).to contain_exactly(product_1)
    end

    it 'filters numerically rather than lexicographically' do
      expect(filter({'cf_custom_weight_gteq' => '3'}).first).to contain_exactly(product_1, product_3)
      expect(filter({'cf_custom_weight_lt' => '3'}).first).to contain_exactly(product_2)
    end

    it 'filters with present and blank' do
      expect(filter({'cf_custom_material_present' => '1'}).first).to contain_exactly(product_1, product_2)
      expect(filter({'cf_custom_material_blank' => '1'}).first).to contain_exactly(product_3)
    end

    it 'composes multiple metafield predicates' do
      products, = filter({'cf_custom_material_present' => '1', 'cf_custom_weight_gteq' => '5'})

      expect(products).to contain_exactly(product_1)
    end

    it 'drops unusable predicates instead of raising' do
      expect(filter({'cf_custom_weight_gteq' => 'abc'}).first).to match_array([product_1, product_2, product_3])
      expect(filter({'cf_bogus_field_eq' => 'x'}).first).to match_array([product_1, product_2, product_3])
    end

    it 'leaves keys whose predicate the field type does not support for Ransack' do
      _, remaining = Spree::Product.with_metafield_filters({'cf_custom_weight_cont' => 'abc'})

      expect(remaining).to eq('cf_custom_weight_cont' => 'abc')
    end

    # The schema hits the DB, so a filter hash with no cf_* keys must not pay for it.
    it 'does not build a schema when no cf_* key is present' do
      expect(Spree::SearchProvider::MetafieldSchema).not_to receive(:new)

      Spree::Product.with_metafield_filters({'name_cont' => 'Blue'})
    end
  end

  describe '.metafield_value_expression' do
    def to_sql(node)
      Spree::Product.connection.visitor.compile(node, Arel::Collectors::SQLString.new)
    end

    it 'casts numeric metafields for the current adapter' do
      expression = Spree::Product.metafield_value_expression(Spree::Metafield.arel_table[:value], 'number')

      expect(to_sql(expression)).to match(/CAST\(.*"value".* AS .+\)|"value"::numeric/)
    end

    it 'leaves text metafields uncast' do
      expression = Spree::Product.metafield_value_expression(Spree::Metafield.arel_table[:value], 'short_text')

      expect(to_sql(expression)).to eq('"spree_metafields"."value"')
    end
  end
end
