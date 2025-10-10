require 'spec_helper'

class MyCustomCreateService
end

describe Spree::Core::Dependencies, type: :model do
  let (:deps) { described_class.new }

  it 'returns the default value' do
    expect(deps.cart_create_service).to eq('Spree::Cart::Create')
  end

  it 'allows to overwrite the value' do
    deps.cart_create_service = MyCustomCreateService
    expect(deps.cart_create_service).to eq MyCustomCreateService
  end
end
