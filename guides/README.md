# api.spreecommerce.com

This is a Spree API resource built with [gatsby](https://www.gatsbyjs.org).

All submissions are welcome. To submit a change, fork this repo, commit your changes, and send us a [pull request](http://help.github.com/send-pull-requests/).

## Setup

TBD

## Audience

When contributing to the Spree documentation, it's important to make sure you understand your audience, and are speaking to them using appropriate terminology that they will both understand and appreciate.

### API

Those reading these guides are likely intermediate- to advanced-level developers. They are likely comfortable with complex technical language and concepts.

### Developer

The audience for guides in the /developer directory includes developers from beginners to advanced. They are expected to already be familiar with Ruby and Rails, but may not have as much experience with deployment and integration with external services.

### Integration

Consumers of this documentation are developers with intermediate to advanced skills. They should already be well-versed in Ruby and Rails; familiar with the core Spree application; and have knowledge of integrating with external services.

### Release Notes

Developers of all degrees of experience are the audience for these documents.

### User

Admins and store owners are the ones most likely to be using this documentation. These guides are where developers can send their clients to teach them how to maintain their store and process orders.

## Styleguide

Not sure how to structure the docs?  Here's what the structure of the
API docs should look like:

TBD

**Note**: We're using [Kramdown Markdown extensions](http://kramdown.gettalong.org/syntax.html), such as definition lists.

### Markdown Conventions

It is helpful to standardize some markdown conventions so readers learn to recognize visual cues as they work their way through the documentation and tutorials. Following are the conventions used for the Spree documentation:

####Class Names####

When referencing the name of a class, it should be capitalized. If you are writing explanatory prose and not a section of code, the class name should be blocked out with tick (`) marks. For example:

    To begin using your custom `User` class, you must first...

Having the namespace for the class is optional, but should be included when omitting it could cause confusion.

An instance of a class should be lowercase, normal font:

    You can view all of the orders for a particular user.

####Buttons, Links, Section Names, Form Elements####

These should always reference the correct label and can have their names quoted. Examples:

* Click the "Filter Results" button to update the results.
* Follow the "Stock Transfers" link.
* Information displayed in the "Purchase Funnel" section gives you information...
* If you check "Receive Stock" while creating a new transfer...

####States, Attributes, Methods, Events, and Parameters####
When referring to the state of an object - an order, for example - the state name should be lowercase and set off with tick (`) marks. For example:

    Orders that are in the `address` state do not have valid shipping and billing addresses assigned to them yet.

This same style is used for attribute names and their settings, method names, event names, parameter names, parameter settings, and data types.

####Path Names####
Path names should be set off with tick (`) marks, and should include enough of the directory structure to make it clear which file is being referenced. For example:

    They are defined in `core/app/models/spree/app_configuration.rb`...

####Adding Emphasis####
Any text that needs to be emphasized should be in _italics_.

    Only the shipping options in the _shipping_ address are presented.

####Terminal Blocks####

You can specify terminal blocks by setting it off with \`\`\`bash.
In addition, you can differentiate commands you are using from output
returned by using the `$` precursor for input and `=>` precursor for output.

```bash
$ irb
$ c = "Hello world"
$ c
=> "Hello world"
```

####Special Blocks####

Certain blocks of text can be wrapped in sets of three characters, which will place them in divs with appropriate CSS classes. They are:

| *** | Notes. |
| !!! | Warnings. |
| $$$ | TODO's |
| --- | A title bar; especially useful for headings for code samples. |

### JSON Responses

TBD

## Development

TBD

## Edge guides

TBD

## TODO

TBD
