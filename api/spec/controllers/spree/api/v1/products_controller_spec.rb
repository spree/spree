require 'spec_helper'
require 'shared_examples/protect_product_actions'

module Spree
  describe Spree::Api::V1::ProductsController do
    render_views

    let!(:product) { create(:product) }
    let!(:inactive_product) { create(:product, :available_on => Time.now.tomorrow, :name => "inactive") }
    let(:attributes) { [:id, :name, :description, :price, :available_on, :permalink, :count_on_hand, :meta_description, :meta_keywords, :taxon_ids] }

    before do
      stub_authentication!
    end

    context "as a normal user" do
      it "retrieves a list of products" do
        api_get :index
        json_response["products"].first.should have_attributes(attributes)
        json_response["count"].should == 1
        json_response["current_page"].should == 1
        json_response["pages"].should == 1
      end

      it "does not list unavailable products" do
        api_get :index
        json_response["products"].first["name"].should_not eq("inactive")
      end

      context "pagination" do
        default_per_page(1)

        it "can select the next page of products" do
          second_product = create(:product)
          api_get :index, :page => 2
          json_response["products"].first.should have_attributes(attributes)
          json_response["total_count"].should == 2
          json_response["current_page"].should == 2
          json_response["pages"].should == 2
        end

        it 'can control the page size through a parameter' do
          create(:product)
          api_get :index, :per_page => 1
          json_response['count'].should == 1
          json_response['total_count'].should == 2
          json_response['current_page'].should == 1
          json_response['pages'].should == 2
        end
      end

      context "jsonp" do
        it "retrieves a list of products of jsonp" do
          api_get :index, {:callback => 'callback'}
          response.body.should =~ /^callback\(.*\)$/
          response.header['Content-Type'].should include('application/javascript')
        end
      end

      it "can search for products" do
        create(:product, :name => "The best product in the world")
        api_get :index, :q => { :name_cont => "best" }
        json_response["products"].first.should have_attributes(attributes)
        json_response["count"].should == 1
      end

      it "gets a single product" do
        product.master.images.create!(:attachment => image("thinking-cat.jpg"))
        product.set_property("spree", "rocks")
        api_get :show, :id => product.to_param
        json_response.should have_attributes(attributes)
        json_response['variants'].first.should have_attributes([:name,
                                                              :is_master,
                                                              :count_on_hand,
                                                              :price])

        json_response["images"].first.should have_attributes([:attachment_file_name,
                                                            :attachment_width,
                                                            :attachment_height,
                                                            :attachment_content_type])

        json_response["product_properties"].first.should have_attributes([:value,
                                                                         :product_id,
                                                                         :property_name])
      end


      context "finds a product by permalink first then by id" do
        let!(:other_product) { create(:product, :permalink => "these-are-not-the-droids-you-are-looking-for") }

        before do
          product.update_attribute(:permalink, "#{other_product.id}-and-1-ways")
        end

        specify do
          api_get :show, :id => product.to_param
          json_response["permalink"].should =~ /and-1-ways/
          product.destroy

          api_get :show, :id => other_product.id
          json_response["permalink"].should =~ /droids/
        end
      end

      it "cannot see inactive products" do
        api_get :show, :id => inactive_product.to_param
        json_response["error"].should == "The resource you were looking for could not be found."
        response.status.should == 404
      end

      it "returns a 404 error when it cannot find a product" do
        api_get :show, :id => "non-existant"
        json_response["error"].should == "The resource you were looking for could not be found."
        response.status.should == 404
      end

      it "can learn how to create a new product" do
        api_get :new
        json_response["attributes"].should == attributes.map(&:to_s)
        required_attributes = json_response["required_attributes"]
        required_attributes.should include("name")
        required_attributes.should include("price")
      end

      it_behaves_like "modifying product actions are restricted"
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can see all products" do
        api_get :index
        json_response["products"].count.should == 2
        json_response["count"].should == 2
        json_response["current_page"].should == 1
        json_response["pages"].should == 1
      end

      # Regression test for #1626
      context "deleted products" do
        before do
          create(:product, :deleted_at => Time.now)
        end

        it "does not include deleted products" do
          api_get :index
          json_response["products"].count.should == 2
        end

        it "can include deleted products" do
          api_get :index, :show_deleted => 1
          json_response["products"].count.should == 3
        end
      end

      it "can create a new product" do
        api_post :create, :product => { :name => "The Other Product",
                                        :price => 19.99 }
        json_response.should have_attributes(attributes)
        response.status.should == 201
      end

      # Regression test for #2140
      context "with authentication_required set to false" do
        before do
          Spree::Api::Config.requires_authentication = false
        end

        after do
          Spree::Api::Config.requires_authentication = true
        end

        it "can still create a product" do
          api_post :create, :product => { :name => "The Other Product",
                                          :price => 19.99 },
                            :token => "fake"
          json_response.should have_attributes(attributes)
          response.status.should == 201
        end
      end

      it "cannot create a new product with invalid attributes" do
        api_post :create, :product => {}
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."
        errors = json_response["errors"]
        errors.delete("permalink") # Don't care about this one.
        errors.keys.should =~ ["name", "price"]
      end

      it "can update a product" do
        api_put :update, :id => product.to_param, :product => { :name => "New and Improved Product!" }
        response.status.should == 200
      end

      it "cannot update a product with an invalid attribute" do
        api_put :update, :id => product.to_param, :product => { :name => "" }
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."
        json_response["errors"]["name"].should == ["can't be blank"]
      end

      it "can delete a product" do
        product.deleted_at.should be_nil
        api_delete :destroy, :id => product.to_param
        response.status.should == 204
        product.reload.deleted_at.should_not be_nil
      end
    end
  end
end
