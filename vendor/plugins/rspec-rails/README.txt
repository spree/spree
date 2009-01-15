= Spec::Rails

* http://rspec.info
* http://rubyforge.org/projects/rspec
* http://github.com/dchelimsky/rspec-rails/wikis
* mailto:rspec-devel@rubyforge.org

== DESCRIPTION:

Behaviour Driven Development for Ruby on Rails.

Spec::Rails (a.k.a. RSpec on Rails) is an RSpec extension that allows you
to drive the development of your RoR application using RSpec.

== FEATURES:

* Use RSpec to independently specify Rails Models, Views, Controllers and Helpers
* Integrated fixture loading
* Special generators for Resources, Models, Views and Controllers that generate RSpec code examples.

== VISION:

For people for whom TDD is a brand new concept, the testing support built into
Ruby on Rails is a huge leap forward. The fact that it is built right in is
fantastic, and Ruby on Rails apps are generally much easier to maintain than
they might have been without such support.

For those of us coming from a history with TDD, and now BDD, the existing
support presents some problems related to dependencies across examples. To
that end, RSpec on Rails supports 4 types of examples. We’ve also built in
first class mocking and stubbing support in order to break dependencies across
these different concerns.

== MORE INFORMATION:

See Spec::Rails::Example for information about the different kinds of example
groups you can use to spec the different Rails components

See Spec::Rails::Matchers for information about Rails-specific
expectations you can set on responses and models, etc.

== INSTALL

* Visit http://github.com/dchelimsky/rspec-rails/wikis for installation instructions.
