require 'spec_helper'

module Spree
  describe Spree::ProductDuplicator do
    let(:product) do
      double 'Product',
        :name => "foo",
        :taxons => [],
        :product_properties => [property],
        :master => variant,
        :has_variants? => false
    end

    let(:new_product) do
      double 'New Product',
        :save! => true
    end

    let(:property) do
      double 'Property'
    end

    let(:new_property) do
      double 'New Property'
    end

    let(:variant) do
      double 'Variant',
        :sku => "12345",
        :price => 19.99,
        :currency => "AUD",
        :images => [image]
    end

    let(:new_variant) do
      double 'New Variant',
        :sku => "12345"
    end

    let(:image) do
      double 'Image',
        :attachment => double('Attachment')
    end

    let(:new_image) do
      double 'New Image'
    end


    before do
      product.should_receive(:dup).and_return(new_product)
      variant.should_receive(:dup).and_return(new_variant)
      image.should_receive(:dup).and_return(new_image)
      property.should_receive(:dup).and_return(new_property)
    end

    it "can duplicate a product" do
      duplicator = Spree::ProductDuplicator.new(product)
      new_product.should_receive(:name=).with("COPY OF foo")
      new_product.should_receive(:taxons=).with([])
      new_product.should_receive(:product_properties=).with([new_property])
      new_product.should_receive(:created_at=).with(nil)
      new_product.should_receive(:updated_at=).with(nil)
      new_product.should_receive(:deleted_at=).with(nil)
      new_product.should_receive(:master=).with(new_variant)

      new_variant.should_receive(:sku=).with("COPY OF 12345")
      new_variant.should_receive(:deleted_at=).with(nil)
      new_variant.should_receive(:images=).with([new_image])
      new_variant.should_receive(:price=).with(variant.price)
      new_variant.should_receive(:currency=).with(variant.currency)

      image.attachment.should_receive(:clone).and_return(image.attachment)

      new_image.should_receive(:assign_attributes).
        with(:attachment => image.attachment).
        and_return(new_image)

      new_property.should_receive(:created_at=).with(nil)
      new_property.should_receive(:updated_at=).with(nil)

      duplicator.duplicate
    end

  end
end

