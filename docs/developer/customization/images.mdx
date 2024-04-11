---
title: Images
section: customization
order: 2
---

# Images

## Overview

This guide explains how to change Product Images dimensions and different storage options for [ActiveStorage](https://edgeguides.rubyonrails.org/active_storage_overview.html) which is the default attachment storage system in Spree.

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

```text
<%= image_tag(main_app.url_for(@product.images.first.attachment.variant(resize: '150x150'))) %>
```

### Using Amazon S3 as storage system

Please refer to the official [Active Storage documentation](https://guides.rubyonrails.org/active_storage_overview.html#amazon-s3-service)

You can also use [Microsoft Azure Storage](https://guides.rubyonrails.org/active_storage_overview.html#microsoft-azure-storage-service) or [Google Cloud Storage](https://guides.rubyonrails.org/active_storage_overview.html#google-cloud-storage-service)

