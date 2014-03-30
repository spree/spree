require 'spec_helper'

describe Spree::StoreController do
  context "redirect_https_to_http enabled" do
    before do
      reset_spree_preferences do |config|
        config.allow_ssl_in_development_and_test = true
        config.redirect_https_to_http = true
      end
    end

    context "receives a non SSL request" do
      it "should not redirect" do
        controller.should_not_receive(:redirect_to)
        spree_get :cart_link
        request.protocol.should eql('http://')
      end
    end

    context "receives a SSL request" do
      before do
        request.env['HTTPS'] = 'on'
      end

      it "should not redirect" do
        controller.should_not_receive(:redirect_to)
        spree_get :cart_link
        request.protocol.should eql('https://')
      end
    end
  end
end