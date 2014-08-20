---
title: General Settings
---

## Introduction

The General Settings section is where you will make site-wide settings about things like your store's name, security, and currency display. You can access this area by going to your Admin Interface, clicking "Configuration", then clicking the "General Settings link."

![General Settings Configuration](/images/user/config/general_settings.jpg)

Each setting on the page is covered below.

### Site Name

The Site Name is what is set in the `<title>` tag of your website. It renders in your browser's title bar on every page of the public-facing area of the site.

![Site Name in Title](/images/user/config/site_name_in_title.jpg)

### Default SEO Title

"SEO" stands for "Search Engine Optimization". It is a way to improve your store's visibility in search results. If you assign a value to the Default SEO Title field, it would override what you had set for the "Site Name" field.

![SEO Title Override](/images/user/config/seo_title_override.jpg)

### Default Meta Keywords

Meta keywords give search engines more information about your store. Use them to supply a list of the words and phrases that are most relevant to the products you offer. These keywords show up in the header of your site. The header is not visible to the casual site visitor, but it does inform your rankings with web browsers.

***
For more information about Search Engine Optimization, try reading the [Google Webmaster Tools topic](https://support.google.com/webmasters/answer/35291?hl=en) on the subject.
***

### Default Meta Description

Whereas meta keywords constitutes a comma-separated list of words and phrases, the meta description is a fuller, prose description of what your store is and does. The phrasing you use can help distinguish you from any other e-commerce websites offering products similar to yours.

### Site URL

The site's URL is the website address for your store, such as "http://myawesomestore.com". This address is used when your application sends out confirmation emails to customers about their purchases.

### Security Settings

Three of the four checkboxes in the "Security Settings" section of your General Settings cover which modes in which [SSL (Secure Sockets Layer)](http://en.wikipedia.org/wiki/Secure_Socket_Layer) can be used on your website. SSL is the way data is encrypted and sent securely through the Internet from the user to the server on which your store resides.

By default, your store will use SSL only in production and staging. Production mode is commonly referred to as "live" mode - real data, real users, real transactions. Staging mode is similar to dress rehearsal - real data, possibly real users, fake transactions.

Development mode is the mode your site's programmer is in as he works on your site. This is typically not deployed anywhere that real users could get to it, so SSL is usually not needed.

Testing mode involves no outside user input at all; it is how your programmer tests functionality in an automated way before the application meets actual end users.

If you're not sure how or whether to use SSL, ask your site's developer for guidance.

The fourth checkbox - "Check for Spree Alerts" - will disable the polling and display of important security and release announcements from Spree Commerce, Inc. These alerts appear on the Admin Interface pages, and may be dismissed after you have read them.

## Currency Settings

The remaining settings all cover how currency is rendered in your store.

![Currency Settings](/images/user/config/currency_settings.jpg)

### Display Currency

If you check this option, the three-letter symbol for the currency of your store is rendered next to each price.

![Show Currency](/images/user/config/show_currency.jpg)

### Hide Cents

Checking this option renders all prices in your store to whole-dollar amounts. The system will not round up to the nearest dollar; it will simply drop anything after the decimal.

### Choose Currency

From this drop-down menu, select the currency of your store. Default is United States Dollars (USD).

### Currency Symbol Location

You can elect to have the currency symbol (if applicable) appear either before or after the amount. Default for USD is to have the "$" sign appear before the amount.

### Currency Decimal Mark

This is where you input what will separate whole amounts from partial amounts (cents). Default is to use a period (".") but you can change it to any character, symbol, or string that you want.

### Currency Thousands Separator

The default setting is ",", which takes a price of $1999.00 and renders it as "$1,999.00" (assuming you left the other settings at default). You can leave the thousands separator blank to have your store render the price as "$1999.00", or change it to anything you like.