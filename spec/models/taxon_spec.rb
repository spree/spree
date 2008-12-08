require File.dirname(__FILE__) + '/../spec_helper'

module TaxonHelper
  def valid_taxon_attributes
    {
      :name => "A Taxon",
      :position => 1
    }
  end
end

describe Taxon do
  include TaxonHelper

  before(:each) do
    @taxonomy = Taxonomy.create(:name => "Test")
    @taxon = Taxon.new
  end

  it "should not be valid when empty" do
    pending "Can it really be valid when empty?"
    @taxon.should_not be_valid
  end

  ['name'].each do |field|
    it "should require #{field}" do
      pending "Is this field mandatory?"
      @taxon.should_not be_valid
      @taxon.errors.full_messages.should include("#{field.intern.l(field).humanize} #{:error_message_blank.l}")
    end
  end
  
  it "should be valid when having correct information" do
    @taxon.attributes = valid_taxon_attributes

    @taxon.should be_valid
  end
  
  it "should set the permalink on create" do
    @taxon = Taxon.create(:name => "foo", :taxonomy => @taxonomy)
    @taxon.permalink.should == "foo/"
  end
  
  it "should update the permalink on update" do
    @taxon = Taxon.create(:name => "foo", :taxonomy => @taxonomy)
    @taxon.update_attribute("name", "fooz")
    @taxon.permalink.should == "fooz/"
  end
  
end
