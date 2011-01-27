require File.dirname(__FILE__) + '/../spec_helper'

describe Country do
  context "shoulda validations" do
    it {should have_many(:states) }
    it {should have_one(:zone_member) }
    it {should have_one(:zone) }
    it {should validate_presence_of(:name) }
    it {should validate_presence_of(:iso_name) }
    it { should have_valid_factory(:country) }
  end

end
