## Spree 2.1.4 (unreleased) ##

* Cached products/show template, which can lead to drastically (65x) faster loading times on product requests.

    Ryan Bigg

* The parts that make up an order's response from /api/orders/:num are cached, which can lead to a 5x improvement of speed for this API endpoint. 80ffb1e739606ac02ac86336ac13a51583bcc225

    Ryan Bigg

* Cached variant objects which can lead to slightly faster loading times (4x) for each variant.

    Ryan Bigg

* Added a route to allow for /api/variants/:id requests

    Ryan Bigg