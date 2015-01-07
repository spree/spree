---
title: Migrating to Spree
section: advanced
---

## Overview

This section explains how to convert existing sites or data sets for
use with Spree. It is a mix of tips and information about the relevant
APIs, and so is definitely intended for developers. After reading it you
should know:

-   techniques for programmatic import of products
-   tips for migrating themes
-   examples of the API in use.

!!!
This documentation on this topic is out of date and we're
working to update it. In the meantime if you see things in here that are
confusing it's possible that they no longer apply, etc.
!!!

## Overview

This guide is a mix of tips and information about the relevant APIs,
intended to help simplify the process of getting a new site set up -
whether you're developing a fresh site or moving from an existing
commerce platform.

The first section discusses various formats of data. Then we look in
detail at import of the product catalogue. Sometimes you may want to
import legacy order details, so there's a short discussion on this.

Finally, there are some tips about how to ease the theme development
process.

## Data Import Format

This part discusses some options for getting data into the system,
including some discussion of using relevant formats.

### Direct SQL import

Can we just format our data as SQL tables and import it directly? In
principle yes, but it takes effort to get the format right,
particularly
when dealing with associations between tables, and you need to ensure
that the new data meets the system's validation rules. It's probably
easier to go the code route.

There are cases where direct import is useful. One key case is when
moving between hosting platforms. Another is when cloning some project:
collaborators can just import a database dump prepared by someone else,
and save the time of the code import.

### Rails Fixtures

Spree uses fixtures to load up the sample data. It's a convenient
format for small collections of data, but can be tricky when working with
large data sets, especially if there are many interconnections and if you
need to be careful with validation.

Note that Rails can dump slices of the database in fixture format. This
is sometimes useful.

### SQL or XML legacy data

This is the case where you are working with legacy data in formats like
SQL or XML, and the question is more how to get the useful data out.

Some systems may be able to export their data in various standard
spreadsheet formats - it's worth checking for this.

Tools like REXML or Nokogiri can be used to parse XML and either build
a spreadsheet representation or execute product-building actions
directly.

For SQL, you can try to build a Rails interface to the data (eg. search
for help with legacy mappings) and dump a simplified format. It might
help
to use views or complex queries to flatten multi-table data into a
single table - which can then be treated like a spreadsheet.

### Spreadsheet format

Most of the information about products can be flattened into
spreadsheet
form, and a 2D table is convenient to work with. Clients are often
comfortable with the format too, and able to supply their inventories
in this format.

For example, your spreadsheet could have the following columns:

### Fixed Details

-    product name
-    master price
-    master sku
-    taxon membership
-    shipping category
-    tax category
-    dimensions and weight
-    list of images
-    description

### Several Properties
-   one column for each property type used in your catalogue

### Variant Specifications
-   option types for the product\
-   one variant per column, each listing the option values and the price/sku

Note that if you know how many fixed columns and properties to expect,
then it's easy to determine which columns represent variants etc.

Some of these columns might have simple punctuation etc. to add structure
to the field. For example, we've used:

-   Html tags in the description
-   WxHxD for a shorthand for the dimensions
-   "green & small = small_green_shirt @ $10.00" to code up a variant which is small and green, has sku *small_green_shirt* and costs $10.
-   "foo\nbar" in the taxons column to encode membership of two taxons
-   "alpha > beta > gamma" in the taxons column to encode membership a particular nesting.

The taxon nesting notation is useful for when 'gamma' doesn't uniquely
identify a taxon (and so you need some context, ie a few ancestor
taxons), or for when the taxon structure isn't fixed in advance and so is
dynamically created as the products are entered.

Another possibility for coding variants is to have each variant on a
separate row, and to leave the fixed fields empty when a row is a variant of the
last-introduced product. This is easier to read.

### Seed code

This is more a technique for getting the data loaded at the right time.
Technically, the product catalogue is *seed data*, standard data which
is needed for the app to work properly.

Spree has several options for loading seed data, but perhaps the easiest
to use here is to put ruby files in *site/db/default/*. These files are
processed when *rake db:seed* is called, and will be processed in the order of the
migration timestamps.

Your ruby script can use one of the XLS or CSV format reading libraries
to read an external file, or if the data set is not too big, you could
embed the CSV text in the script itself, eg. using the **END** convention.

***
If the order of loading is important, choose names for the files
so that alphabetical order gives the correct load order…
***

### Important system-wide settings

A related but important topic is the Spree core settings that your app
will need to function correctly, eg to disable backordering or to
configure the mail subsystem. You can (mostly) set these from the admin
interface, but we recommend using initializers for these. See the
[preferences
guide](preferences.html#persisting-modifications-to-preferences) for
more info.

## Catalog creation

This section covers everything relating to import of a product set,
including the product details, variants, properties and options,
images, and taxons.

### Preliminaries

Let's assume that you are working from a CSV-compatible format, and so
are reading one product per row, and each row contains values for the fixed
details, properties, and variants configuration.

We won't always explicitly save changes to records: we assume that your
upload scripts will call *save* at appropriate times or use
*update_attribute+
etc.

### Products

Products must have at least a name and a price in order to pass
validation, and we set the description too.
```ruby
p = Spree::Product.create :name => 'some product', :price => 10.0,
:description => 'some text here'
```

Observe that the*permalink+ and timestamps are added automatically.
You may want to set the 'meta' fields for SEO purposes.

***
It's important to set the *available_on* field. Without this
being a date in the past, the product won't be listed in the standard
displays.
***

```ruby
p.available_on = Time.now
```

#### The Master variant

Every product has a master variant, and this is created automatically
when the product is created. It is accessible via *p.master*, but note that many
of its fields are accessible through the product via delegation. Example:
*p.price* does the same as *p.master.price*. Delegation also allows field
modification, so *p.price = 2 * p.price* doubles the product's (master) price.

The dimensions and weight fields should be self-explanatory.
The *sku* field holds the product's stock code, and you will want to set
this if the product does not have option variants.

#### Stock levels

If you don't have option variants, then you may also need to register
some stock for the master variant. The exact steps depend on how you
have configured Spree's [inventory system](inventory.html), but most sites
will just need to assign to *p.on_hand*, eg *p.on_hand = 100*.

#### Shipping category

A product's [shipping category](shipments.html#shipping-categories) field
provides product-specific information for the shipping
calculators, eg to indicate that a product requires additional insurance
or can only be surface shipped. If no special conditions are needed, you
can leave this field as nil.
The *Spree::ShippingCategory* model is effectively a wrapper for a
string. You can either generate the list of categories in advance, or use
*where.first_or_create* to reuse previous objects or create new ones
when required.

```ruby
p.shipping_category = Spree::ShippingCategory.where(:name => 'Type A').first_or_create
```

#### Tax category

This is a similar idea to the shipping category, and guides the
calculation of product taxes, eg to distinguish clothing items from electrical
goods.
The model wraps a name *and* a description (both strings), and you can
leave the field as nil if no special treatment is needed.

You can use the *where.first_or_create* technique, though you probably
want to set up the entire [tax configuration](taxation.html) before you start
loading products.

You can also fill in this information automatically at a *later* date,
e.g. use the taxon information to decide which tax categories something
belongs in.

### Taxons

Adding a product to a particular taxon is easy: just add the taxon to
the list of taxons for a product.

```ruby
p.taxons << some_taxon
```

Recall that taxons work like subclassing in OO languages, so a product
in taxon T is also contained in T's ancestors, so you should usually assign a
product to the most specific applicable taxon - and do not need to assign it to
all of the taxon's ancestors.\
However, you can assign products to as many taxons as you want,
including ancestor taxons. This feature is more useful with sibling taxons, e.g.
assigning a red and green shirt to both 'red clothes' and 'green
clothes'.

***
Yes, this also means that child taxons don't have to be distinct, ie
they can overlap.
***

When uploading from a spreadsheet, you might have one or more taxons
listed for a product, and these taxons will be identified by name.
Individual taxon names don't have to be unique, e.g. you could have
'shirts' under 'male clothing', and 'shirts' under 'female clothing'.
In this case, you need some context, eg 'male clothing > shirts' vs.
'female clothing > shirts'.

Do you need to create the taxon structure in advance? Not always: as the
code below shows, it is possible to create taxons as and when they are
needed, but this can be cumbersome for deep hierarchies. One compromise is to
create the top levels (say the top 2 or 3 levels) in advance, then use
the taxon information column to do some product-specific fine tuning.

The following code uses a list of (newline-separated) taxon descriptions-
possibly using 'A > B > C' style of context to assign the taxons for a product. Notice the use of
*where.first_or_create*.

```ruby
# create outside of loop
  main_taxonomy = Spree::Taxonomy.where(:name => 'Products').first_or_create

# inside of main loop
the_taxons = []
taxon_col.split(/[\r\n]*/).each do |chain|
  taxon = nil
  names = chain.split
  names.each do |name|
    taxon = Spree::Taxon.where.first_or_create
  end
  the_taxons << taxon
end
p.taxons = the_taxons

```

You can use similar code to set up other taxonomies, e.g. to have a
taxonomy for brands and product ranges, like 'Guitars' with child
'Acoustic'. You could use various property or option values to drive the
creation of such taxonomies.

### Product Properties

The first step is to create the property 'types'. These should be
known in advance so you can define these at the start of the script. You
should give the internal name and presentation name. For simplicity, the code
examples have these names as the same string.

```ruby
size_prop = Spree::Property.where(name: 'size', presentation: 'Size').first_or_create
```

Then you just set the value for the property-product pair.
Assuming value*size_info+ which is derived from the relevant
column, this means:
```ruby
Spree::ProductProperty.create :property => size_prop, :product => p, :value => size_info
```

#### Product prototypes

The admin interface uses a system of 'prototypes' to speed up data
entry, which seeds a product with a given set of option types and (empty)
property values. It probably isn't so useful when creating products
programmatically, since the code will need to do the hard work of
creating variants and setting properties anyway. However, we mention it
here for completeness.

### Variants

Variants allow different versions of a product to be offered, e.g.
allowing variations in size and color for clothing. If a product comes in only
one configuration, you don't need to use variants - the master variant,
already created, is sufficient.

Otherwise, you need to declare what the allowed option types are (e.g.
size, color, quality rating, etc) for your product, and then create variants
which (usually) have a single option value for each of the product's option
types (e.g. 'small' and 'red' etc).

***
Spree's core generally assumes that each variant has exactly one
option value for each of the product's option types, but the current
code is tolerant of missing values. Certain extensions may be more
strict, e.g. ones for providing advanced variant selection.
***

#### Creating variants

New variants require only a product to be associated with, but it is
useful to set an identifying *sku* code too. The price field is optional: if it is not
explicitly set, the new variant will use the master variant's price (the same applies to
*cost_price* too). You can also set the *weight*, *width*, *height*, and *depth* too.

```ruby
v = Spree::Variant.create :product => p, :sku => "some_sku_code", :price => NNNN
```

***
The price is only copied at creation, so any subsequent changes to
a product's price will need to be copied to all of its variants.
***

Next, you may also want to register some stock for this variant.
The exact steps depend on how you have configured Spree's
[inventory system](inventory.html), but most sites
will just need to assign to *v.on_hand*, eg *v.on_hand = 100*.

You now need to set some option types and values, so customers can
choose between the variants.

#### Option types

The option types to use will vary from product to product, so you will
need to give this information for each product - or assume a default
and only use different names when this column is empty.

You can probably declare most of the option types in advance, and so
just look up the names when required, though for fine control, you can
use the *where.first_or_create* technique, with something like this:

```ruby
p.option_types = option_names_col.map do |name|
  Spree::OptionType.where(:name => name, :presentation => name).first_or_create
end
```

#### Option values

Option values represent the choices possible for some option type.
Again, you could declare them in advance, or use *where.first_or_create*. You'll
probably find it easier to create/retrieve the option values as you create each variant.

Suppose you are using a notation like *"Green & Small = small_green_shirt @ $10.00"*
to encode each variant in the spreadsheet, and this is stored in the variable
*opt_info*. The following extracts the three key pieces of information and sets
the option values for the new variant (see below for variant creation).

```ruby
*,opts,sku,price = opt_info.match\s*=\s*\s*@.\*?)/).to_a
v = Spree::Variant.create :product => p, :sku => sku, :price => price
v.option_values = opts.split.map do |nm|
  Spree::OptionValue.where.first_or_create
end
```

***
You don't have to stick with system-wide option types: you can
create types specifically for groups of products such as a product range from a single
manufacturer. In such cases, the range might have a particular color
scheme and there can be advantages to isolating the scheme's options in its
own type and set of values, rather than trying to work with a more general
setup. It also avoids filling up a type with lots of similar options -
and so reduces the number of options when using faceted search etc. You can
also attach resources like color swatches to the more specific values.

#### Ordering of option values
You might want option values to appear in a certain order, such as by
increasing size or by alphabetical order. The *Spree::OptionValue* model uses
*acts_as_list* for setting the order, and option types will use the *position* field when retrieving
their associated values. The position is scoped to the relevant option type.

If you create option values in advance, just create them in the required
order and the plugin will set the *position* automatically.

```ruby
color_type = Spree::OptionType.create :name => 'Color', :presentation => 'Color'
color_options = %w[Red Blue Green].split.map { |n|
  Spree::OptionValue.create :name => n, :presentation => n,
  :option_type => color_type }
```

Otherwise, you could enforce the ordering*after_ loading up all of the
variants, using something like this:

```ruby
color_type.option_values.sort_by(&:name).each_with_index do |val,pos|
  val.update_attribute(:position, pos + 1)
end
```

#### Further reading

[Steph Skardal](https://github.com/stephskardal) has produced a useful
blog post on [product
optioning](http://blog.endpoint.com/2010/01/rails-ecommerce-spree-hooks-comments.html).
This discusses how the variant option representation works and how she
used it to build an extension for enhanced product option selection.

### Product and Variant images

Spree uses [paperclip](https://github.com/thoughtbot/paperclip) to
manage image attachments and their various size formats. (See the [Customization Guide](logic#product-images) for info on altering the image formats.)
You can attach images to products and to variants - the mechanism is
polymorphic. Given some local image file, the following will associate the image and
create all of the size formats.

```ruby
#for image for product (all variants) represented by master variant
img = Spree::Image.create(:attachment => File.open(path), :viewable => product.master)

#for image for single variant
img = Spree::Image.create(:attachment => File.open(path), :viewable => variant)
```

Paperclip also supports external [storage of images in S3](https://github.com/thoughtbot/paperclip/blob/master/lib/paperclip/storage.rb)
