require File.dirname(__FILE__) + '/../spec_helper'

describe ProductGroup do

  context "shoulda validations" do
    it { should validate_presence_of(:name) }
  end

  context "factory_girl" do
    let(:product_group) { Factory(:product_group) }
    it 'should have a saved record' do
      product_group.new_record?.should be_false
    end
  end
end
