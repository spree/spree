## Spree 2.2.0 (unreleased) ##

*   ApiHelpers attributes can now be extended without overriding instance
    methods. By using the same approach in PermittedAttributes. e.g.

        Spree::Api::ApiHelpers.order_attributes.push :locked_at
    
    Washington Luiz

*   Admin users can set the order channel when importing orders. By sing the
    channel attribute on Order model

    Washington Luiz
