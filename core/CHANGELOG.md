## Spree 2.0.1 (unreleased) ##

*  Sandbox generator and installer now use the correct 2-0-stable branch of spree_auth_devise 
3179a7ac85d4cfcb76622509fc739a0e17668d5a & 759fa3475f5230da3794aed86503913978dde22d.

    *John Dyer and Sean Schofield*

* Revert bump of Rubygems required version which made Spree 2.0.0 unusable on Heroku. 77103dc4f4c93c195ae20f47944f68ef31a7bbe9

    *@Actven*

* Improve performance of `Order#payment_required?` by not updating the totals every time. #3040 #3086

    *Washington Luiz*
    
* Remove after_save callback for stock items backorders processing and
    fixes count on hand updates when there are backordered units #3066

    *Washington Luiz*

* InventoryUnit#backordered_for_stock_item no longer returns readonly objects
    neither return an ActiveRecored::Association. It returns only an array of
    writable backordered units for a given stock item #3066

    *Washington Luiz*
