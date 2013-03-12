require 'spec_helper'
require 'rake'

describe 'running sample' do
  it "executes successfully" do 
    Dir.chdir "spec/dummy" do
      `rake db:seed`
      $?.to_i.should == 0
      `rake spree_sample:load`
      $?.to_i.should == 0
    end
  end

  context "running just db:seed" do
    it "sets default_country_id to United States" do
      Dir.chdir "spec/dummy" do
        `rake db:seed`
        country = Spree::Country.find_by_id(Spree::Config[:default_country_id])
        country.name.should == "United States"
      end
    end
  end
end
