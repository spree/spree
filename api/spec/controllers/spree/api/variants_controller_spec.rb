require 'spec_helper'

module Spree
  describe Api::VariantsController do
    render_views

    let!(:product) { create(:product) }
    let!(:variant) do
      variant = product.master
      variant.option_values << create(:option_value)
      variant
    end
    let!(:attributes) { [:id, :name, :sku, :price, :weight, :height,
                         :width, :depth, :is_master, :cost_price,
                         :permalink, :description] }

    before do
      stub_authentication!
    end

    it "can see a paginated list of variants" do
      api_get :index
      json_response["variants"].first.should have_attributes(attributes)
      json_response["count"].should == 1
      json_response["current_page"].should == 1
      json_response["pages"].should == 1
    end

    it 'can control the page size through a parameter' do
      create(:variant)
      api_get :index, :per_page => 1
      json_response['count'].should == 1
      json_response['current_page'].should == 1
      json_response['pages'].should == 3
    end

    it 'can query the results through a paramter' do
      expected_result = create(:variant, :sku => 'FOOBAR')
      api_get :index, :q => { :sku_cont => 'FOO' }
      json_response['count'].should == 1
      json_response['variants'].first['sku'].should eq expected_result.sku
    end

    it "variants returned contain option values data" do
      api_get :index
      option_values = json_response["variants"].last["option_values"]
      option_values.first.should have_attributes([:name,
                                                 :presentation,
                                                 :option_type_name,
                                                 :option_type_id])
    end

    it "variants returned contain images data" do
      variant.images.create!(:attachment => image("thinking-cat.jpg"))

      api_get :index

      json_response["variants"].last.should have_attributes([:images])
    end

    # Regression test for #2141
    context "a deleted variant" do
      before do
        variant.update_column(:deleted_at, Time.now)
      end

      it "is not returned in the results" do
        api_get :index
        json_response["variants"].count.should == 0
      end

      it "is not returned even when show_deleted is passed" do
        api_get :index, :show_deleted => true
        json_response["variants"].count.should == 0
      end
    end

    context "pagination" do
      it "can select the next page of variants" do
        second_variant = create(:variant)
        api_get :index, :page => 2, :per_page => 1
        json_response["variants"].first.should have_attributes(attributes)
        json_response["total_count"].should == 3
        json_response["current_page"].should == 2
        json_response["pages"].should == 3
      end
    end

    it "can see a single variant" do
      api_get :show, :id => variant.to_param
      json_response.should have_attributes(attributes)
      option_values = json_response["option_values"]
      option_values.first.should have_attributes([:name,
                                                 :presentation,
                                                 :option_type_name,
                                                 :option_type_id])
    end

    it "can see a single variant with images" do
      variant.images.create!(:attachment => image("thinking-cat.jpg"))

      api_get :show, :id => variant.to_param

      json_response.should have_attributes(attributes + [:images])
      option_values = json_response["option_values"]
      option_values.first.should have_attributes([:name,
                                                 :presentation,
                                                 :option_type_name,
                                                 :option_type_id])
    end

    it "can learn how to create a new variant" do
      api_get :new
      json_response["attributes"].should == attributes.map(&:to_s)
      json_response["required_attributes"].should be_empty
    end

    it "cannot create a new variant if not an admin" do
      api_post :create, :variant => { :sku => "12345" }
      assert_unauthorized!
    end

    it "cannot update a variant" do
      api_put :update, :id => variant.to_param, :variant => { :sku => "12345" }
      assert_not_found!
    end

    it "cannot delete a variant" do
      api_delete :destroy, :id => variant.to_param
      assert_not_found!
      lambda { variant.reload }.should_not raise_error
    end

    context "as an admin" do
      sign_in_as_admin!
      let(:resource_scoping) { { :product_id => variant.product.to_param } }

      # Test for #2141
      context "deleted variants" do
        before do
          variant.update_column(:deleted_at, Time.now)
        end

        it "are visible by admin" do
          api_get :index, :show_deleted => 1
          json_response["variants"].count.should == 1
        end
      end

      it "can create a new variant" do
        api_post :create, :variant => { :sku => "12345" }
        json_response.should have_attributes(attributes)
        response.status.should == 201
        json_response["sku"].should == "12345"

        variant.product.variants.count.should == 1
      end

      it "can update a variant" do
        api_put :update, :id => variant.to_param, :variant => { :sku => "12345" }
        response.status.should == 200
      end

      it "can delete a variant" do
        api_delete :destroy, :id => variant.to_param
        response.status.should == 204
        lambda { Spree::Variant.find(variant.id) }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end

  end
end
