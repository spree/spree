## Spree 2.0.8 (unreleased) ##

* Don't serve JS to non XHR requests. Prevents sentive data leaking. Thanks to
  Egor Homakov for pointing that out in Spree codebase.
  See http://homakov.blogspot.com.br/2013/05/do-not-use-rjs-like-techniques.html
  for details.

* 'Only show completed orders' checkbox status will now persist when paging through orders.

    darbs + Ryan Bigg

* Persist search fields acrross requests for sales total report #3906

    Ryan Bigg

* Flash messages for destructive actions in the admin backend are now visible once again. #4032

    Ryan Bigg
