require File.dirname(__FILE__) + '/../spec_helper'

describe Taxonomy do

  context "validation" do
    it { should have_valid_factory(:taxonomy) }
  end

  context "shoulda validations" do
    it {should validate_presence_of(:name) }
  end

end

