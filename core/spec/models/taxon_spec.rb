require File.dirname(__FILE__) + '/../spec_helper'

describe Taxon do
  let(:taxon) { Taxon.new(:name => "Ruby on Rails") }

  context "validation" do
    it { should have_valid_factory(:taxon) }
  end

  context "set_permalink" do

    it "should set permalink correctly when no parent present" do
      taxon.set_permalink
      taxon.permalink.should == "ruby-on-rails"
    end

    context "with parent taxon" do
      before do
        taxon.stub(:parent_id => 123)
        Taxon.should_receive(:find).with(123).and_return(mock_model(Taxon, :permalink => "brands"))
      end

      it "should set permalink correctly when taxon has parent" do
        taxon.set_permalink
        taxon.permalink.should == "brands/ruby-on-rails"
      end

      it "should set permalink correctly with existing permalink present" do
        taxon.permalink = "b/rubyonrails"
        taxon.set_permalink
        taxon.permalink.should == "brands/rubyonrails"
      end

    end

  end

end
