require 'spec_helper'

module Spree
  describe Spree::Api::V1::ImagesController do
    render_views

    let!(:product) { Factory(:product) }
    let!(:attributes) { [:id, :position, :attachment_content_type, 
                         :attachment_file_name, :type, :attachment_updated_at, :attachment_width, 
                         :attachment_height, :alt] }

    before do
      stub_authentication!
    end

    it "can upload a new image for a product" do
      product.images.count.should == 0
      api_post :create, :product_id => product.to_param, :image => { :attachment => file("thinking-cat.jpg")  }
      response.status.should == 201
      json_response.should have_attributes(attributes)
      product.images.count.should == 1
    end

    it "can upload a new image for a variant" do
      product.master.images.count.should == 0
      api_post :create, :variant_id => product.master.to_param, :image => { :attachment => file("thinking-cat.jpg") }
      p json_response
      response.status.should == 201
      json_response.should have_attributes(attributes)
      product.images.count.should == 1
    end
  end
end
