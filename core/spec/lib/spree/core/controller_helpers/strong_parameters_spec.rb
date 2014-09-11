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
end
