require 'spec_helper'

class MyNewSerializer
  include Alba::Resource

  attributes :total
end

class MyCustomCreateService
end

class MyCustomCouponHandler
end

describe Spree::Api::ApiDependencies, type: :model do
  let(:deps) { described_class.new }

  describe 'backwards compatibility' do
    it 'returns the default value as string' do
      expect(deps.storefront_cart_serializer).to eq('Spree::V2::Storefront::CartSerializer')
    end

    it 'allows to overwrite the value' do
      deps.storefront_cart_serializer = MyNewSerializer
      expect(deps.storefront_cart_serializer).to eq MyNewSerializer
    end

    it 'respects global dependencies' do
      original_value = Spree::Dependencies.cart_create_service
      begin
        Spree::Dependencies.cart_create_service = MyCustomCreateService
        expect(deps.storefront_cart_create_service).to eq(MyCustomCreateService)
      ensure
        # Use setter to properly clear memoization
        Spree::Dependencies.cart_create_service = original_value
        Spree::Dependencies.instance_variable_get(:@overrides)&.delete(:cart_create_service)
      end
    end
  end

  describe '#<dependency>_class' do
    it 'returns the constantized class for string values' do
      expect(deps.storefront_cart_serializer_class).to eq Spree::V2::Storefront::CartSerializer
    end

    it 'returns the class directly when set as class' do
      deps.storefront_cart_serializer = MyNewSerializer
      expect(deps.storefront_cart_serializer_class).to eq MyNewSerializer
    end

    it 'resolves proc-based dependencies from core' do
      expect(deps.storefront_cart_create_service_class).to eq Spree::Cart::Create
    end
  end

  describe '#overrides' do
    it 'tracks overridden dependencies' do
      deps.storefront_cart_serializer = MyNewSerializer
      expect(deps.overrides).to have_key(:storefront_cart_serializer)
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
      deps.storefront_cart_serializer = 'NonExistentClass'
      expect { deps.validate! }.to raise_error(Spree::DependencyError)
    end
  end
end

describe 'Spree.api accessor' do
  describe 'Spree.api.<dependency>' do
    it 'returns the resolved class' do
      expect(Spree.api.storefront_cart_serializer).to eq Spree::V2::Storefront::CartSerializer
    end

    it 'responds to dependency methods' do
      expect(Spree.api.respond_to?(:storefront_cart_serializer)).to be true
      expect(Spree.api.respond_to?(:storefront_cart_serializer=)).to be true
    end

    it 'does not respond to non-dependency methods' do
      expect(Spree.api.respond_to?(:non_existent_dependency)).to be false
    end
  end

  describe 'Spree.api.<dependency>=' do
    # Use around hook with ensure to guarantee cleanup even if test fails
    around do |example|
      original_value = Spree::Api::Dependencies.storefront_coupon_handler
      example.run
    ensure
      # Restore original value using setter (which clears memoization)
      Spree::Api::Dependencies.storefront_coupon_handler = original_value
      # Clear override tracking for this test
      Spree::Api::Dependencies.instance_variable_get(:@overrides)&.delete(:storefront_coupon_handler)
    end

    it 'sets the dependency via Spree.api' do
      Spree.api.storefront_coupon_handler = MyCustomCouponHandler
      expect(Spree::Api::Dependencies.storefront_coupon_handler).to eq MyCustomCouponHandler
    end

    it 'returns the new class via Spree.api' do
      Spree.api.storefront_coupon_handler = MyCustomCouponHandler
      expect(Spree.api.storefront_coupon_handler).to eq MyCustomCouponHandler
    end

    it 'tracks override source correctly (not internal routing code)' do
      Spree.api.storefront_coupon_handler = MyCustomCouponHandler
      info = Spree::Api::Dependencies.override_info(:storefront_coupon_handler)

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
