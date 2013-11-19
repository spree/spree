## Spree 2.0.7 (unreleased) ##

*For all commits, please see [the GitHub compare view](https://github.com/spree/spree/compare/v2.0.6...v2.0.7).*

*   A *channel* column was added to the spree_orders table. Users can set
    it when importing orders from other stores. e.g. amazon

    Washington Luiz

*   Converting timestamps to json now give us miliseconds precision (by monkey
    patching ActiveSupport::TimeWithZone#as_json)
    
    Washington Luiz

*   Deface version has been bumped to 1.0.0.

    Ryan Bigg

*   Highline version has been bumped to allow anything > 1.6.18 and < 1.7.x.
    
    Ryan Bigg

*   Active Merchant version has been bumped to 1.42.0. This should fix Money gem dependency problems.

    Ryan Bigg

*   aws-sdk version has been bumped to 1.27.0. This should fix Nokogiri gem dependency problems.

*   Fixed issue where Product#set_property was causing an undefined method when spree_i18n was in use.

    Ryan Bigg

*   Fixed styling issues of select2 boxes in Admin backend. #3854 #3863

    Dominik Staskiewicz

*   Fixed issue where trying to process BogusSimple payments would fail. #3824

    James Strong

*   Added an index to spree_users spree_api_key field. #3884

    Justin Kronz

*   OrderInventory now acknowledges `track_inventory_units` setting and will not create backorders when that setting is set to `false`. b66a98a

    Washington Luiz

*   All adjustments are now updated when an order is updated, rather than just shipping + promotion adjustments. #3960

    John Hawthorn

