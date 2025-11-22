require 'spec_helper'

RSpec.describe 'Spree::Storefront.partials' do
  describe 'integration with Spree::Storefront module' do
    it 'provides access via Spree::Storefront.partials' do
      expect(Spree::Storefront).to respond_to(:partials)
      expect(Spree::Storefront.partials).to be_a(Spree::Core::Partials)
    end

    it 'returns the same instance on multiple calls (memoized)' do
      first_call = Spree::Storefront.partials
      second_call = Spree::Storefront.partials

      expect(first_call).to be(second_call)
    end

    it 'uses the storefront config and environment' do
      partials = Spree::Storefront.partials
      expect(partials.config).to eq(Rails.application.config.spree_storefront)
      expect(partials.environment).to eq(Spree::Storefront::Engine::Environment)
    end
  end

  describe 'storefront partial accessors' do
    let(:partials) { Spree::Storefront.partials }

    it 'defines getter methods for all storefront _partials attributes' do
      expect(partials).to respond_to(:head)
      expect(partials).to respond_to(:body_start)
      expect(partials).to respond_to(:body_end)
      expect(partials).to respond_to(:cart)
      expect(partials).to respond_to(:add_to_cart)
      expect(partials).to respond_to(:remove_from_cart)
      expect(partials).to respond_to(:checkout)
      expect(partials).to respond_to(:checkout_complete)
      expect(partials).to respond_to(:quick_checkout)
      expect(partials).to respond_to(:product)
      expect(partials).to respond_to(:add_to_wishlist)
    end

    it 'defines setter methods for all storefront _partials attributes' do
      expect(partials).to respond_to(:head=)
      expect(partials).to respond_to(:body_start=)
      expect(partials).to respond_to(:body_end=)
      expect(partials).to respond_to(:cart=)
      expect(partials).to respond_to(:add_to_cart=)
      expect(partials).to respond_to(:remove_from_cart=)
      expect(partials).to respond_to(:checkout=)
      expect(partials).to respond_to(:checkout_complete=)
      expect(partials).to respond_to(:quick_checkout=)
      expect(partials).to respond_to(:product=)
      expect(partials).to respond_to(:add_to_wishlist=)
    end
  end

  describe 'getter methods' do
    let(:partials) { Spree::Storefront.partials }

    it 'returns the config values' do
      Rails.application.config.spree_storefront.cart_partials = ['cart_widget']
      expect(partials.cart).to eq(['cart_widget'])
    end

    it 'works with different partial types' do
      Rails.application.config.spree_storefront.product_partials = ['product_info']
      Rails.application.config.spree_storefront.checkout_partials = ['checkout_step']

      expect(partials.product).to eq(['product_info'])
      expect(partials.checkout).to eq(['checkout_step'])
    end
  end

  describe 'setter methods' do
    let(:partials) { Spree::Storefront.partials }

    it 'sets the config values' do
      partials.cart = ['custom_cart']
      expect(Rails.application.config.spree_storefront.cart_partials).to eq(['custom_cart'])
    end

    it 'works with different partial types' do
      partials.product = ['custom_product']
      partials.checkout = ['custom_checkout']

      expect(Rails.application.config.spree_storefront.product_partials).to eq(['custom_product'])
      expect(Rails.application.config.spree_storefront.checkout_partials).to eq(['custom_checkout'])
    end
  end

  describe '#keys' do
    let(:partials) { Spree::Storefront.partials }

    it 'returns all available partial keys' do
      keys = partials.keys
      expect(keys).to include('head')
      expect(keys).to include('body_start')
      expect(keys).to include('body_end')
      expect(keys).to include('cart')
      expect(keys).to include('add_to_cart')
      expect(keys).to include('remove_from_cart')
      expect(keys).to include('checkout')
      expect(keys).to include('checkout_complete')
      expect(keys).to include('quick_checkout')
      expect(keys).to include('product')
      expect(keys).to include('add_to_wishlist')
    end
  end
end
