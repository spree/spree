require 'spec_helper'

describe Spree::Prototype do
  it { should have_and_belong_to_many :properties }
  it { should have_and_belong_to_many :option_types }
  it { should have_and_belong_to_many :taxons }

  it { should validate_presence_of :name }
end
