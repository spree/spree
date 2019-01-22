require 'spec_helper'

class MyCustomCreateService
end

describe Spree::AppDependencies, type: :model do
  let (:deps) { Spree::AppDependencies.new }

  it 'returns the default value' do
    expect(deps.cart_create_service).to eq('Spree::Cart::Create')
  end

  it 'allows to overwrite the value' do
    deps.cart_create_service = MyCustomCreateService
    expect(deps.cart_create_service).to eq MyCustomCreateService
  end
end
