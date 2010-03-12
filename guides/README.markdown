SUMMARY
=======

This project serves as the basis for the online documentation effort for the [Spree ecommerce project](http://spreecommerce.com).  The documentation has been graciously donated by members of our online community.  This work is licensed under the [Creative Commons Attribution-Share Alike 3.0 ](http://creativecommons.org/licenses/by-sa/3.0/) license.  Contributions are encouraged.  Please ask [Sean Schofield](http://github.com/schof) for commit access if you have something to contribute.  If you are thinking about a new guide or major changes to the organization of the existing guides, please be courteous and do this in your own fork so it can be dicussed before merging. 
                                                   
The guides are written in [Textile]() and there is information on the [spree-guides wiki](http://wiki.github.com/railsdog/spree-guides) on the general style to use when writing a guide.  Please stick to the established format and feel free to ask questions on [spree-user](http://groups.google.com/group/spree-user) or #spree if you have any questions. 

To build the entire set of guides simply run the following command

<pre><code>
  $ git clone git://github.com/railsdog/spree-guides.git
  $ cd spree guides
  $ rake guides
</code></pre>
            
You will also need to install the RedCloth gem (4.2.3 or greater) if you do not done so.  Output will be generated in the `output` directory.

To build just one file, say checkout.textile , you can run the spree_guides.rb with an extra argument like below. 

<pre><code>
  $ ruby spree_guides.rb checkout
</code></pre>

You do not need to fork the spree-guides project in order to contribute.  Just send an email to [spree-user](http://groups.google.com/group/spree-user) (be sure to include your github username) and say that you would like to contribute.  We'll add you to the list so you can commit directly to the guides project.  

Please be considerate when making changes to the spree-guides.  If you wish to make major changes to how the documentation is organized then you should use a GitHub fork and ask people to review your proposed changes instead.
