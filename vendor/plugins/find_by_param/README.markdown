NOTE
====

This is a customized version of the original `find_by_param` plugin.  Its been simplified to take advantage of new Rails 2.2 functionality and I've also stripped out some stuff that I really didn't need.  We're using this customized version in the [Spree](http://spreecommerce.com/) commerce platform.


FindByParam
===========

Find_by_param helps you dealing with permalinks and finding objects by our permalink value

class Post < ActiveRecord:Base
 make_permalink :with => :title
end

now you can do Post.find_by_param(...)

If you have a permalink-column find_by_param saves the permalink there and uses that otherwise it just uses the provided attribute.


Example
===========

Post.create(:title => "hey ho let's go!").to_param #=> "hey-ho-lets-go"  (to_param is the method Rails calls to create the URL values)

Post.find_by_param("hey-ho-lets-go") #=> <Post>

Post.find_by_param("is-not-there") #=> nil
Post.find_by_param!("is-not-there") #=> raises ActiveRecord::RecordNotFound

examples:

make_permalink :with => :login
make_permalink :with => :title, :prepend_id=>true


options for make_permalink:

:with: (required) The attribute that should be used as permalink
:field: The name of your permalink column. make_permalink first checks if there is a column. 
:prepend_id: [true|false] Do you want to prepend the ID to the permalink? for URLs like: posts/123-my-post-title - find_by_param uses the ID column to search.
:escape: [true|false] Do you want to escape the permalink value? (strip chars like öä?&?) - actually you must do that




Issues
=======

* Alex Sharp (http://github.com/ajsharp) pointed to an issue with STI. Better call make_permalink in every child class and not only in the parent class..
* write nice docs
* write nicer tests

Copyright (c) 2007 [Michael Bumann - Railslove.com], released under the MIT license
