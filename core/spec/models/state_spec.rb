require File.dirname(__FILE__) + '/../spec_helper'

describe State do
  context "shoulda validations" do
    it {should belong_to(:country) }
    it {should have_one(:zone_member) }
    it {should have_one(:zone) }
    it {should validate_presence_of(:name) }
    it {should validate_presence_of(:country) }
  end

  context "factory_girl" do
    it 'should create a valid record' do
      Factory(:state).new_record?.should be_false
    end
  end
end
