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

  # Regression test for #1436
  context "defining custom image helpers" do
    let(:product) { mock_model(Spree::Product, :images => [], :variant_images => []) }
    before do
      Spree::Image.class_eval do
        attachment_definitions[:attachment][:styles].merge!({:very_strange => '1x1'})
      end
    end

    it "should not raise errors when style exists" do
      expect { very_strange_image(product) }.not_to raise_error
    end

    it "should raise NoMethodError when style is not exists" do
      expect { another_strange_image(product) }.to raise_error(NoMethodError)
    end

  end

  # Regression test for #2034
  context "flash_message" do
    let(:flash) { {:notice => "ok", :foo => "foo", :bar => "bar"} }

    it "should output all flash content" do
      flash_messages
      html = Nokogiri::HTML(helper.output_buffer)
      html.css(".notice").text.should == "ok"
      html.css(".foo").text.should == "foo"
      html.css(".bar").text.should == "bar"
    end

    it "should output flash content except one key" do
      flash_messages(:ignore_types => :bar)
      html = Nokogiri::HTML(helper.output_buffer)
      html.css(".notice").text.should == "ok"
      html.css(".foo").text.should == "foo"
      html.css(".bar").text.should be_empty
    end

    it "should output flash content except some keys" do
      flash_messages(:ignore_types => [:foo, :bar])
      html = Nokogiri::HTML(helper.output_buffer)
      html.css(".notice").text.should == "ok"
      html.css(".foo").text.should be_empty
      html.css(".bar").text.should be_empty
      helper.output_buffer.should == "<div class=\"flash notice\">ok</div>"
    end
  end

  context "link_to_tracking" do
    it "returns tracking link if available" do
      a = link_to_tracking_html(:tracking => '123', :tracking_url => 'http://g.c/?t=123').css('a')

      a.text.should == '123'
      a.attr('href').value.should == 'http://g.c/?t=123'
    end

    it "returns tracking without link if link unavailable" do
      html = link_to_tracking_html(:tracking => '123', :tracking_url => nil)
      html.css('span').text.should == '123'
    end

    it "returns nothing when no tracking" do
      html = link_to_tracking_html(:tracking => nil)
      html.css('span').text.should == ''
    end

    def link_to_tracking_html(options = {})
      node = link_to_tracking(double(:shipment, options))
      Nokogiri::HTML(node.to_s)
    end
  end

  # Regression test for #2396
  context "meta_data_tags" do
    it "truncates a product description to 160 characters" do
      # Because the controller_name method returns "test"
      # controller_name is used by this method to infer what it is supposed
      # to be generating meta_data_tags for
      text = Faker::Lorem.paragraphs(2).join(" ")
      @test = Spree::Product.new(:description => text)
      tags = Nokogiri::HTML.parse(meta_data_tags)
      content = tags.css("meta[name=description]").first["content"]
      assert content.length <= 160, "content length is not truncated to 160 characters"
    end
  end

  context "pretty_time" do
    it "prints in a format" do
      expect(pretty_time(DateTime.new(2012, 5, 6, 13, 33))).to eq "May 06, 2012  1:33 PM"
    end
  end
end
