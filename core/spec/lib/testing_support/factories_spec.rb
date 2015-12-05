require 'spec_helper'

describe Spree::TestingSupport, 'factories' do
  EXCLUDED_FACTORIES = IceNine.deep_freeze(%i[
    customer_return_without_return_items
    stock_packer
    stock_package
    stock_package_fulfilled
  ].to_set)

  private_constant(*constants(false))

  (FactoryGirl.factories.map(&:name).to_set - EXCLUDED_FACTORIES).each do |name|
    specify name.inspect do
      FactoryGirl.create(name)
    end
  end
end
