---
title: About the Code
section: source-code
---

## What is Spree?

Spree is a full featured e-commerce platform written for the Ruby on Rails framework. It is designed to make programming commerce applications easier by making several assumptions about what most developers needs to get started. Spree is a production ready store that can be used "out of the box", but more importantly, it is also a developer tool that can be used as a solid foundation for a more sophisticated application than what is generally possible with traditional open source offerings.

Spree is 100% [open source](http://en.wikipedia.org/wiki/Open_source).  It is licensed under the very permissive [New BSD License](http://spreecommerce.com/license).  You are free to use the software as you see fit, at no charge.  Perhaps more important than the cost, Spree is a true open source community. Spree has hundreds of contributors who have used and improved it while building their own e-commerce solutions.

## Motivation

The goal of the project is to build a complete open source commerce
solution for Ruby on Rails. At the start of this project, the Rails
commerce space was immature and lacking serious solutions for developers
with complex business needs. In the past, Rails has suffered from "small
project mentality." Most open source projects in Rails are maintained by
a single individual and tend to be limited in scope. Spree seeks to
create a large and healthy open source community that developers of
other languages have come to expect.

The founder of Spree was motivated to start the project after failing to
find an existing community in the Rails space dedicated to this vision.
In addition, he was motivated by unsuccessful efforts to use other open
source solutions in other programming languages, including (but not
limited to) the Magento and OSCommerce platforms. These solutions were
deemed to be unsatisfactory when challenged with even the simplest
practical cases of use. 

### Opinionated Commerce

David Heinemeier Hansson (the creator of Rails) is well known for saying
that Rails is "opinionated software." Spree continues this fine
tradition of adopting a few strong (possibly controversial) opinions
which drive its development.

#### No Solution Will Satisfy Everyone

No solution can possibly solve everyone's needs perfectly. There are
simply too many ways in which people do business for us to tailor to
each individual need. Rather than come up short (like so many projects
before it did), Spree's approach is to simply accept this and not even
try. Instead Spree tries to focus on solving 90% of the bulk that most
commerce projects face. The remaining 10% will need to be addressed by
the end developer familiar with the client's exact business
requirements.

#### Online Commerce is not for "Noobs"

Rails developers are the target audience for this application - not
business owners. No serious company would ever try to run an online
store by just paying some fool on Craig's List to install OSCommerce for
them. Serious businesses have complicated needs that require paying one
or more software professionals to solve them. Spree seeks to be the
platform that developers use as the foundation for their project rather
than having to start from scratch or settle for less with other
software.

#### Developers Need Complete Control

Most business owners will not be satisfied with the generic templates
offered by other platforms. Why should they? They want their website to
look just like the other professional sites they see on the web. Most
businesses have very specific shipping and taxation rules as well. Spree
needs to be flexible enough to accommodate most situations. Sensible
defaults should be provided with an eye towards allowing further
customization.

#### Stay Focused

This is perhaps the most important principle behind the design
philosophy. We need to stay focused on core functionality (the 90% that
everybody needs.) For this reason it is not appropriate for Spree to
attempt to become a Content Management System (CMS). There are already
some pretty good Rails based CMS projects out there such as
[Radiant](http://radiantcms.org). CMS is definitely important but it is
a big enough task to warrant its own project. Spree will definitely be
looking at ways to integrate with existing CMS platforms, we just won't
be attempting to reinvent the CMS concept.

## Requirements

This guide is designed for beginners who want to get started with a
Spree application from scratch. It assumes a basic working knowledge of
Ruby on Rails. To get the most out of this guide, you need to have some
prerequisites installed:

-   The [Ruby](http://www.ruby-lang.org/en/downloads) language
-   The [RubyGems](http://rubyforge.org/frs/?group_id=126) packaging
    system
-   The [Ruby on Rails](http://rubyonrails.org/download) gems
-   A working installation of [SQLite](http://www.sqlite.org)
    (preferred), [MySQL](http://www.mysql.com), or
    [PostgreSQL](http://www.postgresql.org)

***
The SQLite database system is the default for development, since it
is relatively easy to set up compared to MySQL or PostgreSQL. For a
production system, we would recommend MySQL or PostgreSQL. Once you've decided,
You might consider using this in development as well, to reduce risk of
database specific bugs.
***

It is highly recommended that you **familiarize yourself with Ruby on
Rails before diving into Spree**. You will find it much easier to follow
what's going on with a Spree application if you understand basic Ruby
syntax.

There are many excellent online resources for learning Ruby on Rails,
including:

-   [Rails Guides](http://guides.rubyonrails.org)
-   [Railscasts (Free Screencasts)](http://railscasts.com/)

There are also some good free resources on the internet for learning
Ruby, including:

-   [Mr. Neighborly's Humble Little Ruby
    Book](http://www.humblelittlerubybook.com)
-   [Programming Ruby](http://www.ruby-doc.org/docs/ProgrammingRuby/)
-   [Why's (Poignant) Guide to
    Ruby](http://mislav.uniqpath.com/poignant-guide/)

## Performance Considerations

Rails 3.1 introduced the concept of the asset pipeline. Unfortunately this causes some significant performance issues when running Spree in development mode. The good news is you can improve performance significantly by using a special precompile task.

```bash
$ bundle exec rake assets:precompile:nondigest
```

Using the precompile rake task in development will prevent any changes to asset files from being automatically included in when you reload the page. You must re-run the precompile task for changes to become available.

Rails also provides the following rake task that will delete the entire `public/assets` directory, this can be helpful to clear out development assets before committing.

```bash
$ bundle exec rake assets:clean
```

It might also be worthwhile to include the public/assets directory in your `.gitignore` file.

## Open Source License

Copyright © 2007-2013, Spree Commerce Inc. and other contributors.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

-   Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-   Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-   Neither the name of Spree Commerce Inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

This software is provided by the copyright holders and contributors "as is" and any express or implied warranties, including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose are disclaimed. In no event shall the copyright owner of contributors be liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption) however caused and on any theory of liability, whether in contract, strict liability, or tort (including negligence or otherwise) arising in any way out of the use of this software, even if advised of the possibility of such damage.
