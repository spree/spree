require 'spec_helper'

describe Spree::BaseHelper, type: :helper do
  include Spree::BaseHelper

  let(:current_store){ create :store }

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
        expect(available_countries.count).to eq(Spree::Country.count)
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
          expect(available_countries).to eq([country])
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
          expect(available_countries.count).to eq(Spree::Country.count)
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

  context "link_to_tracking" do
    it "returns tracking link if available" do
      a = link_to_tracking_html(shipping_method: true, tracking: '123', tracking_url: 'http://g.c/?t=123').css('a')

      expect(a.text).to eq '123'
      expect(a.attr('href').value).to eq 'http://g.c/?t=123'
    end

    it "returns tracking without link if link unavailable" do
      html = link_to_tracking_html(shipping_method: true, tracking: '123', tracking_url: nil)
      expect(html.css('span').text).to eq '123'
    end

    it "returns nothing when no shipping method" do
      html = link_to_tracking_html(shipping_method: nil, tracking: '123')
      expect(html.css('span').text).to eq ''
    end

    it "returns nothing when no tracking" do
      html = link_to_tracking_html(tracking: nil)
      expect(html.css('span').text).to eq ''
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

  # Regression test for #5384
  context "custom image helpers conflict with inproper statements" do
    let(:product) { mock_model(Spree::Product, :images => [], :variant_images => []) }
    before do
      Spree::Image.class_eval do
        attachment_definitions[:attachment][:styles].merge!({:foobar => '1x1'})
      end
    end

    it "should not raise errors when helper method called" do
      expect { foobar_image(product) }.not_to raise_error
    end

    it "should raise NoMethodError when statement with name equal to style name called" do
      expect { foobar(product) }.to raise_error(NoMethodError)
    end

  end

  context "pretty_time" do
    it "prints in a format" do
      expect(pretty_time(DateTime.new(2012, 5, 6, 13, 33))).to eq "May 06, 2012  1:33 PM"
    end
  end
end
