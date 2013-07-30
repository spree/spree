---
title: Zones
---

## Zones

Zones serve as a way to define shipping rules for a particular geographic area. A zone is made up of a set of countries or a set of states. Zones are used within Spree when defining the rules for a Shipping Method. Each Shipping Method is only applicable for a particular Zone. For example, if one of the shipping methods for your store is UPS ground (a U.S.-only shipping carrier) then the Zone for that shipping method should be defined as the United States only. When the customer enters their shipping address during checkout Spree uses that information to determine which zone the customer is in and only presents the Shipping Methods to the customer that are defined for their Zone.

### Creating a Zone

To create a new Zone, go to the Admin Interface, click on the "Configuration" tab, click on the "Zones" link, and then click on the "New Zone" button. Enter a name and description for your new Zone. Decide if you want it to be the default Zone selected when you create a new Shipping Category. Choose whether you want the Zone to be country-based or state-based. Click the "Create" button once complete.

![New Zone](/images/user/shipments/new_zone.jpg)

### Adding Members to a Zone

Once you have a zone set up, you can associate countries or states with it. To do this, go back to the Zones list (from the Admin Interface, click "Configuration" and "Zones"). Click on the "Edit" icon next to the Zone you just created. Click on the "Add Country" or "Add State" button.

![Edit Zone Form](/images/user/shipments/edit_zone.jpg)

Choose a country or state from the drop-down box and click the "Add Country" or "Add State" button. Follow the same steps to add additional countries or states for the Zone.

![Add Multiple Members](/images/user/shipments/add_multi_to_zone.jpg)

Click "Update" once complete.