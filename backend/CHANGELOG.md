## Spree 2.1.4 (unreleased) ##

* Don't serve JS to non XHR requests. Prevents sentive data leaking. Thanks to
  Egor Homakov for pointing that out in Spree codebase.
  See http://homakov.blogspot.com.br/2013/05/do-not-use-rjs-like-techniques.html
  for details.

* 'Only show completed orders' checkbox status will now persist when paging through orders.

    darbs + Ryan Bigg

* Implemented a basic Risk Assessment feature in Spree Backend. Viewing any Order's edit page now shows the following, with a status indicator:

        Payments; link_to new log feature (ie. Number of multiple failed authorization requests)
        AVS response (ie. Billing address not matching credit card)
        CVV response (ie. code not matching)

    Ben Radler (aka lordnibbler)

* Log entries are now displayed in the admin backend for payments.

    Ryan Bigg

* Orders without shipments will now display their line items properly in the admin backend.

    Ryan Bigg

* Fix issue where a controller that inherited from Spree::ResourceController may not be able to find its class.

    Ryan Bigg, tomkrus, Michael Tucker

* Payment amounts are now displayed as "$50.00" Rather than "50.0" on the payments show screen.

    Ryan Bigg

* Shipment states for items on the order screen can now be translated.

    Tiago Amaro

* JavaScript destroy action flash messages are shown once again. #4032

    Ryan Bigg

* The page title for admin screens can now be set with a `content_for :title` block. 

    Ryan Bigg

* Items' SKUs are now displayed on the shipment manifest list. #4045

    Peter Berkenbosch

