## Spree 2.2.0 (unreleased) ##

*   ApiHelpers attributes can now be extended without overriding instance
    methods. By using the same approach in PermittedAttributes. e.g.

        Spree::Api::ApiHelpers.order_attributes.push :locked_at
    
    Washington Luiz

*   Admin users can set the order channel when importing orders. By sing the
    channel attribute on Order model

    Washington Luiz

*   Cached products/show template, which can lead to drastically (65x) faster loading times on product requests. 806319709c4ce9a3d0026e00ec2d07372f51cdb8

    Ryan Bigg

*   The parts that make up an order's response from /api/orders/:num are cached, which can lead to a 5x improvement of speed for this API endpoint. 80ffb1e739606ac02ac86336ac13a51583bcc225

    Ryan Bigg

* Cached variant objects which can lead to slightly faster loading times (4x) for each variant.

    Ryan Bigg

* Added a route to allow for /api/variants/:id requests

    Ryan Bigg