require 'spec_helper'

describe "Template rendering" do

  it 'layout should have canonical tag referencing site url' do
    visit spree.root_path
    find('link[rel=canonical]')[:href].should eql('http://demo.spreecommerce.com/')
  end

end
