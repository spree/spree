require 'spec_helper'

describe Spree::ImageSerializer do
  let(:image) { Spree::Image.new }
  it "contains image URLs" do
    s = Spree::ImageSerializer.new(image)
    json = JSON.parse(s.to_json)
    json['image']['urls'].should == {
      "mini" => "48x48>",
      "small" => "100x100>",
      "product" => "240x240>",
      "large" => "600x600>"
    }
  end
end