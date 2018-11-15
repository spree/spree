---
title: Zones
---

## Zones

Zones serve as a way to define shipping rules for a particular geographic area. A zone is made up of a set of either countries or states. Zones are used within Spree to define the rules for a [Shipping Method](shipping_methods).

Each shipping method can be assigned to only one zone. For example, if one of the shipping methods for your store is UPS Ground (a US-only shipping carrier), then the zone for that shipping method should be defined as the United States.

When the customer enters their shipping address during checkout, Spree uses that information to determine which zone the order is being delivered to, and only presents the shipping methods to the customer that are defined for that zone.

### Creating a Zone

To create a new zone, go to the Admin Interface, click the "Configuration" tab, click the "Zones" link, and then click the "New Zone" button. Enter a name and description for your new zone. Decide if you want it to be the default zone selected for the purposes of calculating sales tax. Choose whether you want the zone to be country-based or state-based. Click the "Create" button once complete.

![New Zone](/images/user/shipments/new_zone.jpg)

### Adding Members to a Zone

Once you have a zone set up, you can associate either countries or states with it. To do this, go back to the Zones list (from the Admin Interface, click "Configuration", then "Zones"). Click the "Edit" icon next to the zone you just created.

![Edit Zone Form](/images/user/shipments/edit_zone.jpg)

Choose a country or state from the drop-down box. Follow the same steps to add additional countries or states for the Zone.

![Add Multiple Members](/images/user/shipments/add_multi_to_zone.jpg)

Click "Update" once complete.

### Removing Members From a Zone

It is easy to remove a state or country from one of your zones. Just go to your Admin Interface and click "Configuration", then "Zones". Click the "Edit" icon next to the zone you want to change. To remove a member of the zone, just click the X icon below its name.

![Remove a Zone Member](/images/user/shipments/remove_zone_member.jpg)

## Next Step

Once you have set up all of the shipping zones you need, it's time to move on to the next Spree shipping component: [Calculators](calculators).