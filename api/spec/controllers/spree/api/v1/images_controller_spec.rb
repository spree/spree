require 'spec_helper'

module Spree
  describe Spree::Api::V1::ImagesController do
    render_views

    let!(:product) { create(:product) }
    let!(:attributes) { [:id, :position, :attachment_content_type,
                         :attachment_file_name, :type, :attachment_updated_at, :attachment_width,
                         :attachment_height, :alt] }

    before do
      stub_authentication!
    end

    it "can upload a new image for a variant" do
      lambda do
        api_post :create,
                 :image => { :attachment => upload_image('thinking-cat.jpg'),
                             :viewable_type => 'Spree::Variant',
                             :viewable_id => product.master.to_param  }
        response.status.should == 201
        json_response.should have_attributes(attributes)
      end.should change(Image, :count).by(1)
    end

    context "working with an existing image" do
      let!(:product_image) { product.master.images.create!(:attachment => image('thinking-cat.jpg')) }

      it "can update image data" do
        product_image.position.should == 1
        api_post :update, :image => { :position => 2 }, :id => product_image.id
        response.status.should == 200
        json_response.should have_attributes(attributes)
        product_image.reload.position.should == 2
      end

      it "can delete an image" do
        api_delete :destroy, :id => product_image.id
        response.status.should == 200
        lambda { product_image.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
