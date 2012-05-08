require 'spec_helper'

describe Spree::ContentController do
  before :each do
    controller.stub :current_spree_user => create(:user)
  end

  it "fires event for #show" do
    # we are using cvv because the file exists in core/views/content
    controller.should_receive(:fire_event).
               with('spree.content.visited', hash_including(:path => "content/cvv"))
    get :show, :path => "cvv"
 end

  it "fires event for content actions like #cvv" do
    controller.should_receive(:fire_event).
               with('spree.content.visited', hash_including(:path => "content/cvv"))
    get :cvv
  end

end