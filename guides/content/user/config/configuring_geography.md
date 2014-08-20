---
title: Zones, Countries, and States
---

## Introduction

Your Spree store allows you to make decisions about which parts of the world you will sell products to, and how those areas are grouped into geographical regions for the convenience of setting [shipping](shipments) and [taxation](taxation) policies. This is accomplished through the use of:

* [zones](#zones)
* [countries](#countries), and
* [states](#states)

### Zones

Within a Spree store, zones are geographical groupings - collections of either states or countries. You can read all about zones in the [zones guide](zones), including how to [create zones](#zones#creating-a-zone), how to [add members to a zone](zones#adding-members-to-a-zone), and how to [remove members from a zone](zones#removing-members-from-a-zone).

### Countries

If you pre-loaded the seed data into your Spree store, then you already have several countries configured. You may want to edit items in this list based on your needs. To access the Countries list, go to your Admin Interface, click "Configuration", then click "Countries".

![Countries List](/images/user/config/countries.jpg)

#### Editing a Country

![Edit Country Icon](/images/user/config/edit_country_icon.jpg)

To edit a country, click the "Edit" icon next to the country.

![Editing Country Form](/images/user/config/editing_country.jpg)

On this page, you can input the country's name, its [ISO Name](https://www.iso.org/obp/ui/#search), and whether or not a state name is required at the time of checkout for orders either billed to or shipped to an address in this country. Click "Update" to save any changes.

### States

A Spree store pre-loaded with seed data already has all of the states in the US configured for it.

![US States](/images/user/config/us_states_list.jpg)

You can edit, remove, or add states to your store to suit your needs.

#### Editing a State

To edit an existing store, click the "Edit" icon next to its name in the list.

![Edit State Icon](/images/user/config/edit_state_icon.jpg)

You can change the name and abbreviation for the state. Click "Update" to save your changes.

![Editing State](/images/user/config/editing_state.jpg)

#### Removing a State

To remove a state from your store, click the "Delete" icon next to its name in the list.

![Deleting State Icon](/images/user/config/edit_state_icon.jpg)

Click "OK" to confirm the deletion.

#### Adding a State

To add a state to your store, first select the country the state belongs to from the "Country" drop-down list.

![Select a Country From the List](/images/user/config/countries_drop_down.jpg)

Next, click the "New State" button. A data entry form appears. Enter the name and abbreviation for the new state, and click "Create".

![New State Form](/images/user/config/new_state_form.jpg)

The new state is created, and you can now edit or delete it like the other states.

![State Added to List](/images/user/config/state_added.jpg)

***
Don't forget to add new states and countries to your store's [zones](zones), so the system can accurately calculate tax and shipping options.
***