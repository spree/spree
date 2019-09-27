---
title: 'Images Customization'
section: customization
order: 2
---

## Overview

This guide explains how to change Product Images dimensions and different storage options for both **ActiveStorage** and **Paperclip**.

## ActiveStorage

ActiveStorage is the default attachment storage system since [Spree 3.6](https://guides.spreecommerce.org/release_notes/spree_3_6_0.html) and [Rails 5.2](https://guides.rubyonrails.org/5_2_release_notes.html).
To read more about ActiveStorage head to the [official documentation](https://edgeguides.rubyonrails.org/active_storage_overview.html).

### Image dimensions

To change the default image dimensions or add new ones you need to create a decorator file `app/models/my_store/spree/image_decorator.rb`:

```ruby
module MyStore
  module Spree
    module ImageDecorator
      module ClassMethods
        def styles
          {
            mini:    '48x48>',
            small:   '100x100>',
            product: '240x240>',
            large:   '600x600>',
          }
        end
      end

      def self.prepended(base)
        base.inheritance_column = nil
        base.singleton_class.prepend ClassMethods
      end
    end
  end
end

::Spree::Image.prepend ::MyStore::Spree::ImageDecorator
```

You can also create image variations on the fly in your templates, eg.

```erb
<%= image_tag(main_app.url_for(@product.images.first.attachment.variant(resize: '150x150'))) %>
```

### Using Amazon S3 as storage system

Please refer to the official [Active Storage documentation](https://guides.rubyonrails.org/active_storage_overview.html#amazon-s3-service)

You can also use [Microsoft Azure Storage](https://guides.rubyonrails.org/active_storage_overview.html#microsoft-azure-storage-service)
or [Google Cloud Storage](https://guides.rubyonrails.org/active_storage_overview.html#google-cloud-storage-service)

## Paperclip

**Paperclip** support was removed in Spree 4.0. To migrate to **ActiveStorage** please read [the official migration guide](https://github.com/thoughtbot/paperclip/blob/master/MIGRATING.md).

### Image dimensions

Until Spree 3.6 we've used Thoughtbot's
[paperclip](https://github.com/thoughtbot/paperclip) gem to manage
images for products. All the normal paperclip options are available on
the `Image` class. If you want to modify the default Spree product and
thumbnail image sizes, simply create an `app/models/spree/image_decorator.rb` file and override the attachment sizes:

```ruby
Spree::Image.class_eval do
  attachment_definitions[:attachment][:styles] = {
    mini: '48x48>', # thumbs under image
    small: '100x100>', # images on category view
    product: '240x240>', # full product image
    large: '600x600>' # light box image
  }
end
```

You may also add additional image sizes for use in your templates
(:micro for shopping cart view, for example).

### Image resizing option syntax

Default behavior is to resize the image and maintain aspect ratio (i.e.
the :product version of a 480x400 image will be 240x200). Some commonly
used options are:

- trailing `#`, image will be centrally cropped, ensuring the requested
  dimensions
- trailing `>`, image will only be modified if it is currently larger
  than the requested dimensions. (i.e. the :small thumb for a 100x100
  original image will be unchanged)

### Using Amazon S3 as storage system

Start with adding AWS-SDK to your `Gemfile` with: `gem 'aws-sdk-s3'`, then install the gem by running `bundle install`.

When that's done you need to configure Spree to use Amazon S3. You can add an initializer or just use the spree.rb initializer located at `config/intializers/spree.rb`.

```ruby
attachment_config = {
  s3_credentials: {
    access_key_id:     ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    bucket:            ENV['S3_BUCKET_NAME']
  },

  storage:        :s3,
  s3_region:      ENV['S3_REGION'],
  s3_headers:     { "Cache-Control" => "max-age=31557600" },
  s3_protocol:    "https",
  bucket:         ENV['S3_BUCKET_NAME'],
  url:            ":s3_domain_url",

  path:           "/:class/:id/:style/:basename.:extension",
  default_url:    "/:class/:id/:style/:basename.:extension",
}

attachment_config.each do |key, value|
  Spree::Image.attachment_definitions[:attachment][key.to_sym] = value
end

```

Note that I use the `url: ":s3_domain_url"` setting, this enabled the DNS lookup for your images without specifying the specific zone endpoint. You need to use a bucket name that makes a valid subdomain. So do not use dots if you are planning on using the DNS lookup config.
