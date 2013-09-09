require 'spec_helper'
require 'webmock'

module Spree
  describe Spree::Alert do
    include WebMock::API

    before { WebMock.enable! }

    it "gets current alerts" do
      alerts_json = File.read(File.join(fixture_path, "alerts.json"))

      stub_request(:get, "alerts.spreecommerce.com/alerts.json").
        with(:query => {
          version: Spree.version,
          name: Spree::Config[:site_name],
          host: "localhost",
          rails_env: Rails.env,
          rails_version: Rails.version
        }).to_return(alerts_json)
      alerts = Spree::Alert.current("localhost")
      alerts.first.should == {
        "created_at"=>"2012-07-13T11:47:58Z",
        "updated_at"=>"2012-07-13T11:47:58Z",
        "url"=>"http://spreecommerce.com/blog/2012/07/12/spree-1-0-6-released/",
        "id"=>24,
        "url_name"=>"Blog Post",
        "severity"=>"Release",
        "message"=>"Spree 1.0.6 Released"
      }
    end
  end
end
