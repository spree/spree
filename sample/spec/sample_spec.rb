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
end
