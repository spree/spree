## Pull requests

We gladly accept pull requests to add new features, bug fixes, documentation updated and overall any improvements to the codebase! All contributions (even the smallest ones) are welcome!

Here's a quick guide:

1. Fork the repo

2. Clone the fork to your local machine

3. Run `bundle install` inside `spree` directory

4. Create a sandbox environment

  ```bash
  bundle exec rake sandbox
  ```

5. To run a sandbox application:

  ```bash
  cd sandbox
  bundle exec rails s
  ```

6. Create new branch then make changes and add tests for your changes. Only
refactoring and documentation changes require no new tests. If you are adding
functionality or fixing a bug, we need tests!

7. Run the tests. [See instructions](https://guides.spreecommerce.org/developer/tutorials/developing_spree.html#running-tests)

8. Push to your fork and submit a pull request. If the changes will apply cleanly
to the master branch, you will only need to submit one pull request.

  Don't do pull requests against `-stable` branches. Always target the master branch. Any bugfixes we'll backport to those branches.

At this point, you're waiting on us. We like to at least comment on, if not
accept, pull requests within three business days (and, typically, one business
day). We may suggest some changes or improvements or alternatives.

Some things that will increase the chance that your pull request is accepted,
taken straight from the Ruby on Rails guide:

* Use Rails idioms and helpers
* Include tests that fail without your code, and pass with it
* Update the documentation, the surrounding one, examples elsewhere, guides,
  whatever is affected by your contribution

Syntax:

* Two spaces, no tabs.
* No trailing whitespace. Blank lines should not have any space.
* Use &&/|| over and/or.
* `MyClass.my_method(my_arg)` not `my_method( my_arg )` or `my_method my_arg`.
* `a = b` and not `a=b`.
* `a_method { |block| ... }` and not `a_method { | block | ... }`
* Follow the conventions you see used in the source already.
* -> symbol over lambda
* Ruby 1.9 hash syntax `{ key: value }` over Ruby 1.8 hash syntax `{ :key => value }`
* Alphabetize the class methods to keep them organized

And in case we didn't emphasize it enough: we love tests!
