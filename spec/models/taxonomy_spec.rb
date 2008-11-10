require File.dirname(__FILE__) + '/../spec_helper'

module TaxonomyHelper
  def valid_taxonomy_attributes
    {
      :name => "A Taxonomy"
    }
  end
end

describe Taxonomy do
  include TaxonomyHelper

  before(:each) do
    @taxonomy = Taxonomy.new
  end

  it "should not be valid when empty" do
    pending "Can it really be valid when empty?"
    @taxonomy.should_not be_valid
  end

  ['name', 'root'].each do |field|
    it "should require #{field}" do
      pending "Is this field mandatory?"
      @taxonomy.should_not be_valid
      @taxonomy.errors.full_messages.should include("#{field.intern.l(field).humanize} #{:error_message_blank.l}")
    end
  end
  
  it "should be valid when having correct information" do
    @taxonomy.attributes = valid_taxonomy_attributes

    @taxonomy.should be_valid
  end
  
end
