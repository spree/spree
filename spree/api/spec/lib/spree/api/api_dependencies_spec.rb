require 'spec_helper'

class MyNewSerializer
  include Alba::Resource

  attributes :total
end

class MyCustomFieldSerializer
end

describe Spree::Api::ApiDependencies, type: :model do
  let(:deps) { described_class.new }

  describe 'defaults' do
    it 'returns the default value as string' do
      expect(deps.product_serializer).to eq('Spree::Api::V3::ProductSerializer')
    end

    it 'allows to overwrite the value' do
      deps.product_serializer = MyNewSerializer
      expect(deps.product_serializer).to eq MyNewSerializer
    end
  end

  describe '#<dependency>_class' do
    it 'returns the constantized class for string values' do
      expect(deps.order_serializer_class).to eq Spree::Api::V3::OrderSerializer
    end

    it 'returns the class directly when set as class' do
      deps.order_serializer = MyNewSerializer
      expect(deps.order_serializer_class).to eq MyNewSerializer
    end
  end

  describe '#overrides' do
    it 'tracks overridden dependencies' do
      deps.order_serializer = MyNewSerializer
      expect(deps.overrides).to have_key(:order_serializer)
    end
  end

  describe '#current_values' do
    it 'returns all dependencies with metadata' do
      values = deps.current_values
      expect(values).to be_an(Array)
      expect(values.first).to include(:name, :current, :default, :overridden)
    end
  end

  describe '#validate!' do
    it 'raises Spree::DependencyError for invalid dependencies' do
      deps.order_serializer = 'NonExistentClass'
      expect { deps.validate! }.to raise_error(Spree::DependencyError)
    end
  end
end

describe 'Spree.api accessor' do
  describe 'Spree.api.<dependency>' do
    it 'returns the resolved class' do
      expect(Spree.api.order_serializer).to eq Spree::Api::V3::OrderSerializer
    end

    it 'responds to dependency methods' do
      expect(Spree.api.respond_to?(:order_serializer)).to be true
      expect(Spree.api.respond_to?(:order_serializer=)).to be true
    end

    it 'does not respond to non-dependency methods' do
      expect(Spree.api.respond_to?(:non_existent_dependency)).to be false
    end
  end

  describe 'Spree.api.<dependency>=' do
    # Use around hook with ensure to guarantee cleanup even if test fails
    around do |example|
      original_value = Spree::Api::Dependencies.custom_field_serializer
      example.run
    ensure
      # Restore original value using setter (which clears memoization)
      Spree::Api::Dependencies.custom_field_serializer = original_value
      # Clear override tracking for this test
      Spree::Api::Dependencies.instance_variable_get(:@overrides)&.delete(:custom_field_serializer)
    end

    it 'sets the dependency via Spree.api' do
      Spree.api.custom_field_serializer = MyCustomFieldSerializer
      expect(Spree::Api::Dependencies.custom_field_serializer).to eq MyCustomFieldSerializer
    end

    it 'returns the new class via Spree.api' do
      Spree.api.custom_field_serializer = MyCustomFieldSerializer
      expect(Spree.api.custom_field_serializer).to eq MyCustomFieldSerializer
    end

    it 'tracks override source correctly (not internal routing code)' do
      Spree.api.custom_field_serializer = MyCustomFieldSerializer
      info = Spree::Api::Dependencies.override_info(:custom_field_serializer)

      # Should point to this spec file, not api.rb method_missing
      expect(info[:source]).to include('api_dependencies_spec.rb')
      expect(info[:source]).not_to include('lib/spree/api.rb')
    end
  end

  describe 'Spree.api.dependencies' do
    it 'returns the raw dependencies object' do
      expect(Spree.api.dependencies).to eq Spree::Api::Dependencies
    end
  end
end
