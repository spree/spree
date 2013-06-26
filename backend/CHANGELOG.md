## Spree 2.1.0 (unreleased) ##

*   No longer requires all jquery ui modules. Extensions should include the
    ones they need on their own manifest file. #3237

    *Washington Luiz*
    
*   Symbolize attachment style keys on ImageSettingController otherwise users
    would get *undefined method `processors' for "48x48>":String>* since
    paperclip can't handle key strings. #3069 #3080

    *Washington Luiz*

*   Split line items across shipments. Use this to move line items between 
    existing shipments or to create a new shipment on an order from existing
    line items.

    *John Dyer*

*   Fixed display of "Total" price for a line item on a shipment. #3135

    *John Dyer
