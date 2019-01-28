require 'spec_helper'

class MyNewSerializer
  include FastJsonapi::ObjectSerializer

  attributes :total
end

class MyCustomCreateService
end

describe Spree::ApiDependencies, type: :model do
  let (:deps) { Spree::ApiDependencies.new }

  it 'returns the default value' do
    expect(deps.storefront_cart_serializer).to eq('Spree::V2::Storefront::CartSerializer')
  end

  it 'allows to overwrite the value' do
    deps.storefront_cart_serializer = MyNewSerializer
    expect(deps.storefront_cart_serializer).to eq MyNewSerializer
  end

  it 'respects global dependecies' do
    Spree::Dependencies.cart_create_service = MyCustomCreateService
    expect(deps.storefront_cart_create_service).to eq(MyCustomCreateService)
  end
end
