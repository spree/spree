require 'spec_helper'

class MyNewSerializer
  include Alba::Resource

  attributes :total
end

describe Spree::Api::ApiDependencies, type: :model do
  let(:deps) { described_class.new }

  describe '#<dependency>_class' do
    it 'returns the constantized class for string values' do
      expect(deps.order_serializer_class).to eq Spree::Api::V3::OrderSerializer
    end

    it 'returns the class directly when set as class' do
      deps.order_serializer = MyNewSerializer
      expect(deps.order_serializer_class).to eq MyNewSerializer
    end

    it 'resolves proc-based dependencies from core' do
      expect(deps.order_serializer_class).to eq Spree::Api::V3::OrderSerializer
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

  describe 'Spree.api.dependencies' do
    it 'returns the raw dependencies object' do
      expect(Spree.api.dependencies).to eq Spree::Api::Dependencies
    end
  end
end
