require 'spec_helper'

describe Spree::BaseHelper do
  include Spree::BaseHelper

  context "available_countries" do
    let(:country) { create(:country) }

    before do
      3.times { create(:country) }
    end

    context "with no checkout zone defined" do
      before do
        Spree::Config[:checkout_zone] = nil
      end

      it "return complete list of countries" do
        available_countries.count.should == Spree::Country.count
      end
    end

    context "with a checkout zone defined" do
      context "checkout zone is of type country" do
        before do
          @country_zone = create(:zone, :name => "CountryZone")
          @country_zone.members.create(:zoneable => country)
          Spree::Config[:checkout_zone] = @country_zone.name
        end

        it "return only the countries defined by the checkout zone" do
          available_countries.should == [country]
        end
      end

      context "checkout zone is of type state" do
        before do
          state_zone = create(:zone, :name => "StateZone")
          state = create(:state, :country => country)
          state_zone.members.create(:zoneable => state)
          Spree::Config[:checkout_zone] = state_zone.name
        end

        it "return complete list of countries" do
          available_countries.count.should == Spree::Country.count
        end
      end
    end
  end

  # Regression test for #889
  context "seo_url" do
    let(:taxon) { stub(:permalink => "bam") }
    it "provides the correct URL" do
      seo_url(taxon).should == "/t/bam"
    end
  end

  # Regression test for #1436
  context "defining custom image helpers" do
    let(:product) { mock_model(Spree::Product, :images => []) }
    before do
      Spree::Image.class_eval do
        attachment_definitions[:attachment][:styles].merge!({:very_strange => '1x1'})
      end
    end

    it "should not raise errors when style exists" do
      lambda { very_strange_image(product) }.should_not raise_error
    end

    it "should raise NoMethodError when style is not exists" do
      lambda { another_strange_image(product) }.should raise_error(NoMethodError)
    end

  end

  # Regression test for #2034
  context "flash_message" do
    let(:flash) { {:notice => "ok", :foo => "foo", :bar => "bar"} }

    it "should output all flash content" do
      flash_messages
      helper.output_buffer.should == "<div class=\"flash notice\">ok</div><div class=\"flash foo\">foo</div><div class=\"flash bar\">bar</div>"
    end

    it "should output flash content except one key" do
      flash_messages(:ignore_types => :bar)
      helper.output_buffer.should == "<div class=\"flash notice\">ok</div><div class=\"flash foo\">foo</div>"
    end

    it "should output flash content except some keys" do
      flash_messages(:ignore_types => [:foo, :bar])
      helper.output_buffer.should == "<div class=\"flash notice\">ok</div>"
    end
  end
end
