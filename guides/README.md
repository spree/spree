SUMMARY
=======

This project serves as the basis for the online documentation effort for the [Spree ecommerce project](http://spreecommerce.com).  The documentation has been graciously donated by members of our online community.  This work is licensed under the [Creative Commons Attribution-Share Alike 3.0 ](http://creativecommons.org/licenses/by-sa/3.0/) license.  Contributions are encouraged.  Please ask [Sean Schofield](http://github.com/schof) for commit access if you have something to contribute.  If you are thinking about a new guide or major changes to the organization of the existing guides, please be courteous and do this in your own fork so it can be dicussed before merging.

Please stick to the established format and feel free to ask questions on [spree-user](http://groups.google.com/group/spree-user) or #spree if you have any questions.

To build the entire set of guides simply run the following command

<pre><code>
  $ git clone git://github.com/spree/spree-guides.git
  $ cd spree-guides
  $ bundle install
  $ guides build
</code></pre>

You can force a rebuild of all of the guides using

```
$ guides build --clean
```

You can also specify that you want to rebuild just a few of the guides

```
$ guides build --only=checkout adjustments
```

Finally, you can also preview the guides while you work

```
$ guides preview
```

You do not need to fork the spree-guides project in order to contribute.  Just send an email to [spree-user](http://groups.google.com/group/spree-user) (be sure to include your github username) and say that you would like to contribute.  We'll add you to the list so you can commit directly to the guides project.

Please be considerate when making changes to the spree-guides.  If you wish to make major changes to how the documentation is organized then you should use a GitHub fork and ask people to review your proposed changes instead.
