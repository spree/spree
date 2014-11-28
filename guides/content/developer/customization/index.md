---
title: "Customization Overview"
section: customization
---

This guide explains the customization and extension techniques you can
use to adapt a generic Spree store to meet your specific design and
functional requirements, including:

-   Explanation of how customizations are organized and shared
-   Overview of the three major customization options: View, Asset &
    Logic

For more detailed information and a step-by-step tutorial on creating
extensions for Spree be sure to checkout the
[Extensions](extensions_tutorial.html) guide.

### Managing Customizations

Spree supports three methods for managing and organizing your
customizations. While they all support exactly the same options for
customization they differ in terms of re-usability. So before you get
started you need to decide what sort of customizations you are going to
make.

#### Application Specific

Application specific customizations are the most common type of
customization applied to Spree. It's generally used by developers and
designers to tweak Spree's behaviour or appearance to match a particular
business's operating procedures, branding, or provide a unique feature.

All application specific customizations are stored within the host
application where Spree is installed (please see the Installation
section of the [Getting Started with Spree](getting_started_tutorial.html) guide,
for how to setup the host application). Application customizations are
not generally shared or re-used in any way.

#### Extension

Extensions enable developers to enhance or add functionality to Spree,
and are generally discrete pieces of functionality that are shared and
intended to be installed in multiple Spree implementations.

Extensions are generally distributed as ruby gems and implemented as
standard Rails 3 engines so they provide a natural way to bundle all the
changes needed to implement larger features.

Visit the [Extension Registry](http://spreecommerce.com/extensions) to
get an idea of the type and volume of extensions available.

#### Theme

Themes are designed to overhaul the entire look and feel of a Spree
store (or its administration system). Themes are distributed in exactly
the same manner as extensions, but don't generally include logic
customizations.

***
For more implementation details on Extensions and Themes please
refer to the [Extensions & Themes](extensions_tutorial.html) guide.
***

### Customization Options

Once you've decided how you're going to manage your customizations, you
then need to choose the correct option to achieve the desired changes.

#### View Customizations

Allows you to change and/or extend the look and feel of a Spree store
(and its administration system). For details see the [View
Customization](view_customization.html) guide.

#### Asset Customizations

Allows changing the static assets provided by Spree, this includes
stylesheets, JavaScript files and images. For details see the [Asset
Customization](asset_customization.html) guide.

#### Use S3 for storage

Setup Spree to store your images on S3. For details see the
 [Use S3 for storage](s3_storage.html) guide

#### Logic Customizations

Enables the changing and/or extension of the logic of Spree to meet your
specific business requirements. For details see the [Logic
Customization](logic_customization.html) guide.
