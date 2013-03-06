# api.spreecommerce.com

This is a Spree API resource built with [nanoc][nanoc].

All submissions are welcome. To submit a change, fork this repo, commit your changes, and send us a [pull request](http://help.github.com/send-pull-requests/).

## Setup

Ruby 1.9 is required to build the site.

Get the nanoc gem, plus kramdown for markdown parsing:

    bundle install

You can see the available commands with nanoc:

    nanoc -h

Nanoc has [some nice documentation](http://nanoc.stoneship.org/docs/3-getting-started/) to get you started.  Though if you're mainly concerned with editing or adding content, you won't need to know much about nanoc.

[nanoc]: http://nanoc.stoneship.org/

## Styleguide

Not sure how to structure the docs?  Here's what the structure of the
API docs should look like:

    # API title

    ## API endpoint title

        [VERB] /path/to/endpoint.json

    ### Parameters

    name
    : description

    ### Input (request json body)

    <%= json :field => "sample value" %>

    ### Response

    <%= headers 200, :pagination => true, 'X-Custom-Header' => "value" %>
    <%= json :resource_name %>

**Note**: We're using [Kramdown Markdown extensions](http://kramdown.rubyforge.org/syntax.html), such as definition lists.

### JSON Responses

We specify the JSON responses in ruby so that we don't have to write
them by hand all over the docs.  You can render the JSON for a resource
like this:

    <%= json :product %>

This looks up `Spree::Resources::PRODUCT` in `lib/resources.rb`.

Some actions return arrays.  You can modify the JSON by passing a block:

    <%= json(:issue) { |hash| [hash] } %>

### Terminal blocks

You can specify terminal blocks with `pre.terminal` elements.  It'd be
nice if Markdown could do this more cleanly...

    <pre class="terminal">
    $ curl foobar
    ....
    </pre>

This isn't a `curl` tutorial though, I'm not sure every API call needs
to show how to access it with `curl`.

## Development

Nanoc compiles the site into static files living in `./output`.  It's
smart enough not to try to compile unchanged files:

    $ nanoc compile
    Loading site data...
    Compiling site...
      create  [0.03s]  output/changes/index.html
      create  [0.00s]  output/CNAME
      create  [0.02s]  output/changes.atom
      create  [0.01s]  output/index.html
      create  [0.09s]  output/addresses/index.html
      create  [0.01s]  output/changelog/index.html
      create  [0.02s]  output/countries/index.html
      create  [0.03s]  output/index.html
      create  [0.08s]  output/order/line_items/index.html
      create  [0.15s]  output/order/payments/index.html
      create  [0.02s]  output/order/shipments/index.html

    Site compiled in 5.81s.

You can setup whatever you want to view the files.  If you have the adsf
gem, however (I hope so, it was in the Gemfile), you can start Webrick:

    $ nanoc view
    $ open http://localhost:3000

Compilation times got you down?  Use `autocompile`!

    $ nanoc autocompile

This starts a web server too, so there's no need to run `nanoc view`.
One thing: remember to add trailing slashes to all nanoc links!

## Deploy

    $ bundle exec cap deploy

## TODO

* Integrate through a simple hurl.it app for live API calls.
* Write a task for verifying JSON Resource examples against the actual
  API.
