require 'spec_helper'

class MyCustomCreateService
end

class MyCustomAddItemService
end

describe Spree::Core::Dependencies, type: :model do
  let(:deps) { described_class.new }

  describe 'backwards compatibility' do
    it 'returns the default value as string' do
      expect(deps.cart_create_service).to eq('Spree::Cart::Create')
    end

    it 'allows to overwrite the value with a class' do
      deps.cart_create_service = MyCustomCreateService
      expect(deps.cart_create_service).to eq MyCustomCreateService
    end

    it 'allows to overwrite the value with a string' do
      deps.cart_create_service = 'MyCustomCreateService'
      expect(deps.cart_create_service).to eq 'MyCustomCreateService'
    end

    it 'works with constantize for string values' do
      expect(deps.cart_create_service.constantize).to eq Spree::Cart::Create
    end
  end

  describe '#<dependency>_class' do
    it 'returns the constantized class for string values' do
      expect(deps.cart_create_service_class).to eq Spree::Cart::Create
    end

    it 'returns the class directly when set as class' do
      deps.cart_create_service = MyCustomCreateService
      expect(deps.cart_create_service_class).to eq MyCustomCreateService
    end

    it 'memoizes the resolved class' do
      deps.cart_create_service_class
      expect(deps.instance_variable_get(:@cart_create_service_resolved)).to eq Spree::Cart::Create
    end

    it 'clears memoization when value changes' do
      deps.cart_create_service_class
      deps.cart_create_service = MyCustomCreateService
      expect(deps.instance_variable_defined?(:@cart_create_service_resolved)).to be false
    end
  end

  describe '#overrides' do
    it 'returns empty hash when no overrides' do
      expect(deps.overrides).to eq({})
    end

    it 'tracks overridden dependencies' do
      deps.cart_create_service = MyCustomCreateService
      expect(deps.overrides).to have_key(:cart_create_service)
    end

    it 'includes override metadata' do
      deps.cart_create_service = MyCustomCreateService
      override = deps.overrides[:cart_create_service]

      expect(override[:value]).to eq MyCustomCreateService
      expect(override[:source]).to be_a(String)
      expect(override[:set_at]).to be_a(Time)
    end
  end

  describe '#overridden?' do
    it 'returns false for non-overridden dependencies' do
      expect(deps.overridden?(:cart_create_service)).to be false
    end

    it 'returns true for overridden dependencies' do
      deps.cart_create_service = MyCustomCreateService
      expect(deps.overridden?(:cart_create_service)).to be true
    end

    it 'works with string argument' do
      deps.cart_create_service = MyCustomCreateService
      expect(deps.overridden?('cart_create_service')).to be true
    end
  end

  describe '#override_info' do
    it 'returns nil for non-overridden dependencies' do
      expect(deps.override_info(:cart_create_service)).to be_nil
    end

    it 'returns override info for overridden dependencies' do
      deps.cart_create_service = MyCustomCreateService
      info = deps.override_info(:cart_create_service)

      expect(info[:value]).to eq MyCustomCreateService
      expect(info[:source]).to include('app_dependencies_spec.rb')
    end
  end

  describe '#current_values' do
    it 'returns all dependencies with metadata' do
      values = deps.current_values
      expect(values).to be_an(Array)
      expect(values.first).to include(:name, :current, :default, :overridden)
    end

    it 'marks non-overridden dependencies correctly' do
      cart_create = deps.current_values.find { |v| v[:name] == :cart_create_service }
      expect(cart_create[:overridden]).to be false
      expect(cart_create[:current]).to eq cart_create[:default]
    end

    it 'marks overridden dependencies correctly' do
      deps.cart_create_service = MyCustomCreateService
      cart_create = deps.current_values.find { |v| v[:name] == :cart_create_service }

      expect(cart_create[:overridden]).to be true
      expect(cart_create[:current]).to eq MyCustomCreateService
      expect(cart_create[:default]).to eq 'Spree::Cart::Create'
    end
  end

  describe '#validate!' do
    it 'raises Spree::DependencyError for invalid dependencies' do
      deps.cart_create_service = 'NonExistentClass'
      expect { deps.validate! }.to raise_error(Spree::DependencyError)
    end

    it 'includes dependency names in error message' do
      deps.cart_create_service = 'NonExistentClass'
      deps.cart_add_item_service = 'AnotherNonExistentClass'
      expect { deps.validate! }.to raise_error(Spree::DependencyError, /cart_create_service/)
    end
  end
end

describe 'Spree module dependency accessors' do
  # These tests use the global Spree::Dependencies instance
  # We need to be careful to restore original values after tests

  describe 'Spree.<dependency>' do
    it 'returns the resolved class' do
      expect(Spree.cart_create_service).to eq Spree::Cart::Create
    end

    it 'responds to dependency methods' do
      expect(Spree.respond_to?(:cart_create_service)).to be true
      expect(Spree.respond_to?(:cart_create_service=)).to be true
    end

    it 'does not respond to non-dependency methods' do
      expect(Spree.respond_to?(:non_existent_dependency)).to be false
    end
  end

  describe 'Spree.<dependency>=' do
    let(:original_value) { Spree::Dependencies.cart_add_item_service }

    after do
      # Restore original value using setter (which clears memoization)
      Spree::Dependencies.cart_add_item_service = original_value
      # Clear override tracking for this test
      Spree::Dependencies.instance_variable_get(:@overrides)&.delete(:cart_add_item_service)
    end

    it 'sets the dependency via Spree module' do
      Spree.cart_add_item_service = MyCustomAddItemService
      expect(Spree::Dependencies.cart_add_item_service).to eq MyCustomAddItemService
    end

    it 'returns the new class via Spree module' do
      Spree.cart_add_item_service = MyCustomAddItemService
      expect(Spree.cart_add_item_service).to eq MyCustomAddItemService
    end

    it 'tracks override source correctly (not internal routing code)' do
      Spree.cart_add_item_service = MyCustomAddItemService
      info = Spree::Dependencies.override_info(:cart_add_item_service)

      # Should point to this spec file, not core.rb method_missing
      expect(info[:source]).to include('app_dependencies_spec.rb')
      expect(info[:source]).not_to include('lib/spree/core.rb')
    end
  end
end
