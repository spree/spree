require File.dirname(__FILE__)+'/../test_helper'
require 'urligence'

class PhotosController
  include Urligence
end

class UrligenceTest < Test::Unit::TestCase  
  def setup
    @controller = PhotosController.new
    @tag   = stub(:class => stub(:name => "Tag"), :to_param => 'awesomestuff')
    @photo = stub(:class => stub(:name => "Photo"), :to_param => 1)
  end
  
  context "with one object" do
    setup do
      setup_mocks "/photos/#{@photo.to_param}", :photo, @photo
    end
    
    context "urligence" do
      should "return the correct path" do
        assert_equal @expected_path, @controller.urligence(@photo, :path)
      end
    end
    
    context "smart_url" do
      should "return the correct url" do
        assert_equal @expected_url, @controller.smart_url(@photo)
      end
    end
    
    context "smart_path" do
      should "return the correct path" do
        assert_equal @expected_path, @controller.smart_path(@photo)
      end
    end
  end
  
  context "with two objects" do
    setup do
      setup_mocks "/tags/#{@tag.to_param}/photos/#{@photo.to_param}", :tag_photo, @tag, @photo
    end
    
    should "return the correct path" do
      assert_equal @expected_path, @controller.urligence(@tag, @photo, :path)
    end
  end
  
  context "with a namespace as first param" do
    setup do
      setup_mocks "/admin/tags/#{@tag.to_param}/photos/#{@photo.to_param}", :admin_tag_photo, @tag, @photo
    end
    
    should "return the correct path" do
      assert_equal @expected_path, @controller.urligence(:admin, @tag, @photo, :path)
    end
  end
  
  context "with many nil options anywhere in the arguments" do
    setup do
      setup_mocks "/tags/#{@tag.to_param}/photos/#{@photo.to_param}", :tag_photo, @tag, @photo
    end
    
    should "return the correct path" do
      assert_equal @expected_path, @controller.urligence(nil, nil, nil, @tag, nil, @photo, nil, :path)
    end
  end
  
  context "with a symbol as the last parameter" do
    setup do
      setup_mocks "/tags/#{@tag.to_param}/photos", :tag_photos, @tag
    end

    should "use that as the last fragment of the url" do
      assert_equal @expected_path, @controller.urligence(@tag, :photos, :path)
    end
  end
  
  context "with a symbol as the only parameter" do
    setup do
      setup_mocks "/photos", :photos
    end

    should "use that as the only url fragment" do
      assert_equal @expected_path, @controller.urligence(nil, :photos, :path)
    end
  end
  
  context "with a namespace, and a plural symbol" do
    setup do
      setup_mocks "/admin/products", :admin_products
    end

    should "call the correct url handler" do
      assert_equal @expected_path, @controller.urligence(:admin, :products, :path)
    end
  end
  
  context "with only symbols" do
    setup do
      setup_mocks '/admin/products/new', :new_admin_products
    end
    
    should "return the correct path" do
      assert_equal @expected_path, @controller.urligence(:new, :admin, :products, :path)
    end
  end
  
  context "with array parameters for specifying the names of routes that don't match the class name of the object" do
    setup do
      setup_mocks '/something_tags/1', :something_tag, @tag
    end
    
    context "urligence" do
      should "use the name of the symbol as the url fragment" do
        assert_equal @expected_path, @controller.urligence([:something_tag, @tag], :path)
      end
    end
    
    context "smart_url" do
      should "return the correct path" do
        assert_equal @expected_url, @controller.smart_url([:something_tag, @tag])
      end
    end
    
    context "smart_path" do
      should "return the correct path" do
        assert_equal @expected_path, @controller.smart_path([:something_tag, @tag])
      end
    end
  end
  
  context "with array parameters and a namespace" do
    setup do
      setup_mocks '/admin/something_tags/1', :admin_something_tag, @tag
    end

    should "return the correct url" do
      assert_equal @expected_path, @controller.urligence(:admin, [:something_tag, @tag], :path)
    end
  end
  
  context "with array parameters, a namespace, and an ending symbol" do
    setup do
      setup_mocks '/admin/something_tags/1/photos', :admin_something_tag_photos, @tag
    end

    should "return the correct url" do
      assert_equal @expected_path, @controller.urligence(:admin, [:something_tag, @tag], :photos, :path)
    end
  end
  
  context "with array parameters, a symbol namespace, and normal model parameters" do
    setup do
      setup_mocks '/admin/something_tags/1/photos/1', :admin_something_tag_photo, @tag, @photo
    end

    should "return the correct url" do
      assert_equal @expected_path, @controller.urligence(:admin, [:something_tag, @tag], @photo, :path)
    end
  end
  
  context "hash_for" do
    context "url" do
      setup do
        @controller.stubs(:hash_for_photo_tag_url).with(:id => @tag.to_param, :photo_id => @photo.to_param).returns("something")
      end

      should "return the correct hash" do
        assert_equal "something", @controller.hash_for_smart_url(@photo, @tag)
      end
    end
    
    context "path" do
      setup do
        @photo_tag = stub(:class => stub(:name => "PhotoTag"), :to_param => 'awesomestuff')
        @controller.stubs(:hash_for_photo_tag_path).with(:id => @tag.to_param, :photo_id => @photo.to_param).returns("something")
      end

      should "return the correct hash" do
        assert_equal "something", @controller.hash_for_smart_path(@photo, [:tag, @photo_tag])
      end
    end
    
    context "collection path" do
      setup do
        @controller.stubs(:hash_for_photos_path).with({}).returns('something')
      end

      should "call the correct methods" do
        assert_equal 'something', @controller.hash_for_smart_path(:photos)
      end
    end
  end
  
  private
    def setup_mocks(expected_path, method, *params)
      @expected_path = expected_path
      @controller.stubs("#{method}_path".to_sym).with(*params).returns(@expected_path)
      @controller.stubs("#{method}_url".to_sym).with(*params).returns(@expected_url = "http://localhost#{@expected_path}")
      @controller.stubs("hash_for_#{method}_url".to_sym).with(*params).returns(@expected_hash = @expected_url)
    end
end
