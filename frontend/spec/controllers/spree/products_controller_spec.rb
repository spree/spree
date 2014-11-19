require 'spec_helper'

describe Spree::ProductsController, :type => :controller do
  let!(:product) { create(:product, :available_on => 1.year.from_now) }

  # Regression test for #1390
  it "allows admins to view non-active products" do
    allow(controller).to receive_messages :spree_current_user => mock_model(Spree.user_class, :has_spree_role? => true, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    spree_get :show, :id => product.to_param
    expect(response.status).to eq(200)
  end

  it "cannot view non-active products" do
    spree_get :show, :id => product.to_param
    expect(response.status).to eq(404)
  end

  it "should provide the current user to the searcher class" do
    user = mock_model(Spree.user_class, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    allow(controller).to receive_messages :spree_current_user => user
    expect_any_instance_of(Spree::Config.searcher_class).to receive(:current_user=).with(user)
    spree_get :index
    expect(response.status).to eq(200)
  end

  # Regression test for #2249
  it "doesn't error when given an invalid referer" do
    current_user = mock_model(Spree.user_class, :has_spree_role? => true, :last_incomplete_spree_order => nil, :generate_spree_api_key! => nil)
    allow(controller).to receive_messages :spree_current_user => current_user
    request.env['HTTP_REFERER'] = "not|a$url"

    # Previously a URI::InvalidURIError exception was being thrown
    expect { spree_get :show, :id => product.to_param }.not_to raise_error
  end

  # Regression tests for #2308 & Spree::Core::ControllerHelpers::SSL
  context "force_ssl enabled" do
    context "receive a SSL request" do
      before do
        request.env['HTTPS'] = 'on'
      end

      it "should not redirect to http" do
        expect(controller).not_to receive(:redirect_to)
        spree_get :index
        expect(request.protocol).to eql('https://')
      end
    end
  end

  context "redirect_https_to_http enabled" do
    before do
      reset_spree_preferences do |config|
        config.allow_ssl_in_development_and_test = true
        config.redirect_https_to_http = true
      end
    end

    context "receives a non SSL request" do
      it "should not redirect" do
        expect(controller).not_to receive(:redirect_to)
        spree_get :index
        expect(request.protocol).to eql('http://')
      end
    end

    context "receives a SSL request" do
      before do
        request.env['HTTPS'] = 'on'
        request.path = "/products?foo=bar"
      end

      it "should redirect to http" do
        spree_get :index
        expect(response).to redirect_to("http://#{request.host}/products?foo=bar")
        expect(response.status).to eq(301)
      end
    end
  end
end
