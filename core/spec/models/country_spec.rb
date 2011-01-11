require File.dirname(__FILE__) + '/../spec_helper'

describe Country do
  context "shoulda validations" do
    it {should have_many(:states) }
    it {should have_one(:zone_member) }
    it {should have_one(:zone) }
    it {should validate_presence_of(:name) }
    it {should validate_presence_of(:iso_name) }
  end

  context "factory_girl" do
    it 'should create a valid record' do
      Factory(:country).new_record?.should be_false
    end
  end
end
