## Spree 2.0.7 (unreleased) ##

*   A *channel* column was added to the spree_orders table. Users can set
    it when importing orders from other stores. e.g. amazon

    Washington Luiz

*   Converting timestamps to json now give us miliseconds precision (by monkey
    patching ActiveSupport::TimeWithZone#as_json)
    
    Washington Luiz
