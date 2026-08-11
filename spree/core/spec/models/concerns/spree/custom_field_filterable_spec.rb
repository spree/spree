# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::CustomFieldFilterable do
  let(:store) { @default_store }

  let!(:product_1) { create(:product, name: 'Blue Shirt') }
  let!(:product_2) { create(:product, name: 'Red Pants') }
  let!(:product_3) { create(:product, name: 'Blue Jacket') }

  let!(:material) do
    create(:custom_field_definition, :short_text_field, :searchable, namespace: 'custom', key: 'material')
  end
  let!(:weight) do
    create(:custom_field_definition, :number_field, :sortable, namespace: 'custom', key: 'weight')
  end

  before do
    product_1.set_custom_field(material, 'Wool-Blend')
    product_2.set_custom_field(material, 'cotton')
    product_1.set_custom_field(weight, '10')
    product_2.set_custom_field(weight, '2')
    product_3.set_custom_field(weight, '3.5')
  end

  def filter(filters)
    scope, remaining = Spree::Product.with_custom_field_filters(filters)
    [scope.to_a, remaining]
  end

  describe '.with_custom_field_filters' do
    it 'returns the untouched scope and filters when no cf_* keys are present' do
      scope, remaining = Spree::Product.with_custom_field_filters({'name_cont' => 'Blue'})

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

    it 'composes multiple custom_field predicates' do
      products, = filter({'cf_custom_material_present' => '1', 'cf_custom_weight_gteq' => '5'})

      expect(products).to contain_exactly(product_1)
    end

    it 'drops unusable predicates instead of raising' do
      expect(filter({'cf_custom_weight_gteq' => 'abc'}).first).to match_array([product_1, product_2, product_3])
      expect(filter({'cf_bogus_field_eq' => 'x'}).first).to match_array([product_1, product_2, product_3])
    end

    it 'leaves keys whose predicate the field type does not support for Ransack' do
      _, remaining = Spree::Product.with_custom_field_filters({'cf_custom_weight_cont' => 'abc'})

      expect(remaining).to eq('cf_custom_weight_cont' => 'abc')
    end

    # The schema hits the DB, so a filter hash with no cf_* keys must not pay for it.
    it 'does not build a schema when no cf_* key is present' do
      expect(Spree::SearchProvider::CustomFieldSchema).not_to receive(:new)

      Spree::Product.with_custom_field_filters({'name_cont' => 'Blue'})
    end
  end

  describe '.custom_field_value_expression' do
    let(:connection) { Spree::Product.connection }
    # Identifier quoting differs per adapter (backticks on MySQL, double
    # quotes elsewhere), so build the expected column reference from the
    # connection rather than hardcoding either form.
    let(:quoted_column) do
      "#{connection.quote_table_name(Spree::CustomField.table_name)}.#{connection.quote_column_name('value')}"
    end

    def to_sql(node)
      connection.visitor.compile(node, Arel::Collectors::SQLString.new)
    end

    it 'casts numeric custom_fields for the current adapter' do
      expression = Spree::Product.custom_field_value_expression(Spree::CustomField.arel_table[:value], 'number')

      # PostgreSQL renders `CAST(x AS numeric)`, MySQL `CAST(x AS DECIMAL(30, 10))`,
      # SQLite `CAST(x AS REAL)` — all wrap the column in a cast.
      expect(to_sql(expression)).to match(/\ACAST\(#{Regexp.escape(quoted_column)} AS .+\)\z/)
    end

    it 'leaves text custom_fields uncast' do
      expression = Spree::Product.custom_field_value_expression(Spree::CustomField.arel_table[:value], 'short_text')

      expect(to_sql(expression)).to eq(quoted_column)
    end
  end
end
