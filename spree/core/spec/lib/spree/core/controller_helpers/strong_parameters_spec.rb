require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::StrongParameters
end

describe Spree::Core::ControllerHelpers::StrongParameters, type: :controller do
  controller(FakesController) {}

  describe '#permitted_attributes' do
    it 'returns Spree::PermittedAttributes module' do
      expect(controller.permitted_attributes).to eq Spree::PermittedAttributes
    end
  end

  describe '#permitted_payment_attributes' do
    it 'returns Array class' do
      expect(controller.permitted_payment_attributes.class).to eq Array
    end
  end

  describe '#permitted_checkout_attributes' do
    it 'returns Array class' do
      expect(controller.permitted_checkout_attributes.class).to eq Array
    end
  end

  describe '#permitted_order_attributes' do
    it 'returns Array class' do
      expect(controller.permitted_order_attributes.class).to eq Array
    end
  end

  describe '#permitted_product_attributes' do
    it 'returns Array class' do
      expect(controller.permitted_product_attributes.class).to eq Array
    end
  end

  describe '#permitted_store_attributes' do
    it 'returns Array class' do
      expect(controller.permitted_store_attributes.class).to eq Array
    end
  end

  # Regression test for #13003
  describe 'return_quantity in permitted attributes' do
    it 'includes return_quantity in return_authorization nested return_items_attributes' do
      nested = Spree::PermittedAttributes.return_authorization_attributes.find { |a| a.is_a?(Hash) && a.key?(:return_items_attributes) }
      expect(nested).not_to be_nil
      expect(nested[:return_items_attributes]).to include(:return_quantity)
    end

    it 'includes return_quantity in customer_return nested return_items_attributes' do
      nested = Spree::PermittedAttributes.customer_return_attributes.find { |a| a.is_a?(Hash) && a.key?(:return_items_attributes) }
      expect(nested).not_to be_nil
      expect(nested[:return_items_attributes]).to include(:return_quantity)
    end
  end
end
