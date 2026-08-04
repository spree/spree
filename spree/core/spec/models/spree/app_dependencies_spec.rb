require 'spec_helper'

class MyCustomAddItemService
end

class MyCustomAddItemService
end

describe Spree::Core::Dependencies, type: :model do
  let(:deps) { described_class.new }

  describe 'backwards compatibility' do
    it 'returns the default value as string' do
      expect(deps.cart_add_item_workflow).to eq('Spree::Carts::AddItem')
    end

    it 'allows to overwrite the value with a class' do
      deps.cart_add_item_workflow = MyCustomAddItemService
      expect(deps.cart_add_item_workflow).to eq MyCustomAddItemService
    end

    it 'allows to overwrite the value with a string' do
      deps.cart_add_item_workflow = 'MyCustomAddItemService'
      expect(deps.cart_add_item_workflow).to eq 'MyCustomAddItemService'
    end

    it 'works with constantize for string values' do
      expect(deps.cart_add_item_workflow.constantize).to eq Spree::Carts::AddItem
    end
  end

  describe '#<dependency>_class' do
    it 'returns the constantized class for string values' do
      expect(deps.cart_add_item_workflow_class).to eq Spree::Carts::AddItem
    end

    it 'returns the class directly when set as class' do
      deps.cart_add_item_workflow = MyCustomAddItemService
      expect(deps.cart_add_item_workflow_class).to eq MyCustomAddItemService
    end

    it 'memoizes the resolved class' do
      deps.cart_add_item_workflow_class
      expect(deps.instance_variable_get(:@cart_add_item_workflow_resolved)).to eq Spree::Carts::AddItem
    end

    it 'clears memoization when value changes' do
      deps.cart_add_item_workflow_class
      deps.cart_add_item_workflow = MyCustomAddItemService
      expect(deps.instance_variable_defined?(:@cart_add_item_workflow_resolved)).to be false
    end
  end

  describe '#overrides' do
    it 'returns empty hash when no overrides' do
      expect(deps.overrides).to eq({})
    end

    it 'tracks overridden dependencies' do
      deps.cart_add_item_workflow = MyCustomAddItemService
      expect(deps.overrides).to have_key(:cart_add_item_workflow)
    end

    it 'includes override metadata' do
      deps.cart_add_item_workflow = MyCustomAddItemService
      override = deps.overrides[:cart_add_item_workflow]

      expect(override[:value]).to eq MyCustomAddItemService
      expect(override[:source]).to be_a(String)
      expect(override[:set_at]).to be_a(Time)
    end
  end

  describe 'legacy *_service workflow keys' do
    it 'stashes writes without touching the workflow seam and reads them back' do
      expect(Spree::Deprecation).to receive(:warn).with(/NO LONGER CONSULTED/).ordered
      expect(Spree::Deprecation).to receive(:warn).with(/cart_add_item_service is deprecated/).ordered

      deps.cart_add_item_service = 'MyCustomAddItemService'
      expect(deps.cart_add_item_service).to eq('MyCustomAddItemService')
      expect(deps.cart_add_item_workflow).to eq('Spree::Carts::AddItem')
    end

    it 'falls back to the workflow class for legacy reads with no stash' do
      allow(Spree::Deprecation).to receive(:warn)
      expect(deps.cart_add_item_service).to eq('Spree::Carts::AddItem')
    end
  end

  describe 'legacy service rename keys' do
    it 'stashes shipment_update_service writes without touching the fulfillment seam' do
      allow(Spree::Deprecation).to receive(:warn)

      deps.shipment_update_service = 'MyCustomShipmentUpdate'
      expect(deps.shipment_update_service).to eq('MyCustomShipmentUpdate')
      expect(deps.fulfillment_update_service).to eq('Spree::Fulfillments::Update')
    end

    it 'falls back to the fulfillment service for legacy reads with no stash' do
      allow(Spree::Deprecation).to receive(:warn)
      expect(deps.shipment_update_service).to eq('Spree::Fulfillments::Update')
    end
  end

  describe 'legacy keys through the Spree top-level resolver' do
    it 'sets and resolves without raising, leaving the workflow seam untouched' do
      allow(Spree::Deprecation).to receive(:warn)
      stub_const('MyBootTimeAddItem', Class.new)

      expect { Spree.cart_add_item_service = 'MyBootTimeAddItem' }.not_to raise_error
      expect(Spree.cart_add_item_service).to eq(MyBootTimeAddItem)
      expect(Spree.cart_add_item_workflow).to eq(Spree::Carts::AddItem)
      expect(Spree::Deprecation).to have_received(:warn).at_least(:twice)
    ensure
      Spree::Dependencies.instance_variable_set(:@legacy_workflow_overrides, nil)
    end
  end

  describe '#overridden?' do
    it 'returns false for non-overridden dependencies' do
      expect(deps.overridden?(:cart_add_item_workflow)).to be false
    end

    it 'returns true for overridden dependencies' do
      deps.cart_add_item_workflow = MyCustomAddItemService
      expect(deps.overridden?(:cart_add_item_workflow)).to be true
    end

    it 'works with string argument' do
      deps.cart_add_item_workflow = MyCustomAddItemService
      expect(deps.overridden?('cart_add_item_workflow')).to be true
    end
  end

  describe '#override_info' do
    it 'returns nil for non-overridden dependencies' do
      expect(deps.override_info(:cart_add_item_workflow)).to be_nil
    end

    it 'returns override info for overridden dependencies' do
      deps.cart_add_item_workflow = MyCustomAddItemService
      info = deps.override_info(:cart_add_item_workflow)

      expect(info[:value]).to eq MyCustomAddItemService
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
      cart_create = deps.current_values.find { |v| v[:name] == :cart_add_item_workflow }
      expect(cart_create[:overridden]).to be false
      expect(cart_create[:current]).to eq cart_create[:default]
    end

    it 'marks overridden dependencies correctly' do
      deps.cart_add_item_workflow = MyCustomAddItemService
      cart_create = deps.current_values.find { |v| v[:name] == :cart_add_item_workflow }

      expect(cart_create[:overridden]).to be true
      expect(cart_create[:current]).to eq MyCustomAddItemService
      expect(cart_create[:default]).to eq 'Spree::Carts::AddItem'
    end
  end

  describe '#validate!' do
    it 'raises Spree::DependencyError for invalid dependencies' do
      deps.cart_add_item_workflow = 'NonExistentClass'
      expect { deps.validate! }.to raise_error(Spree::DependencyError)
    end

    it 'includes dependency names in error message' do
      deps.cart_add_item_workflow = 'NonExistentClass'
      deps.cart_add_item_workflow = 'AnotherNonExistentClass'
      expect { deps.validate! }.to raise_error(Spree::DependencyError, /cart_add_item_workflow/)
    end
  end
end

describe 'Spree module dependency accessors' do
  # These tests use the global Spree::Dependencies instance
  # We need to be careful to restore original values after tests

  describe 'Spree.<dependency>' do
    it 'returns the resolved class' do
      expect(Spree.cart_add_item_workflow).to eq Spree::Carts::AddItem
    end

    it 'responds to dependency methods' do
      expect(Spree.respond_to?(:cart_add_item_workflow)).to be true
      expect(Spree.respond_to?(:cart_add_item_workflow=)).to be true
    end

    it 'does not respond to non-dependency methods' do
      expect(Spree.respond_to?(:non_existent_dependency)).to be false
    end
  end

  describe 'Spree.<dependency>=' do
    # Use around hook with ensure to guarantee cleanup even if test fails
    around do |example|
      original_value = Spree::Dependencies.cart_add_item_workflow
      example.run
    ensure
      # Restore original value using setter (which clears memoization)
      Spree::Dependencies.cart_add_item_workflow = original_value
      # Clear override tracking for this test
      Spree::Dependencies.instance_variable_get(:@overrides)&.delete(:cart_add_item_workflow)
    end

    it 'sets the dependency via Spree module' do
      Spree.cart_add_item_workflow = MyCustomAddItemService
      expect(Spree::Dependencies.cart_add_item_workflow).to eq MyCustomAddItemService
    end

    it 'returns the new class via Spree module' do
      Spree.cart_add_item_workflow = MyCustomAddItemService
      expect(Spree.cart_add_item_workflow).to eq MyCustomAddItemService
    end

    it 'tracks override source correctly (not internal routing code)' do
      Spree.cart_add_item_workflow = MyCustomAddItemService
      info = Spree::Dependencies.override_info(:cart_add_item_workflow)

      # Should point to this spec file, not core.rb method_missing
      expect(info[:source]).to include('app_dependencies_spec.rb')
      expect(info[:source]).not_to include('lib/spree/core.rb')
    end
  end
end
