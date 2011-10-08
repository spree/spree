require 'spec_helper'

describe Spree::Taxonomy do

  context "validation" do
    it { should have_valid_factory(:taxonomy) }
  end

  context "shoulda validations" do
    it {should validate_presence_of(:name) }
  end

end

