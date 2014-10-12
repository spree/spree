require 'spec_helper'

describe Spree::Property do
  it { should have_and_belong_to_many :prototypes }

  it { should have_many :product_properties }
  it { should have_many :products }

  it { should validate_presence_of :name }
  it { should validate_presence_of :presentation }
end
