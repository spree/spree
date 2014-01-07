## Spree 2.1.4 (unreleased) ##

* Cached products/show template, which can lead to drastically (65x) faster loading times on product requests.

    Ryan Bigg

* The parts that make up an order's response from /api/orders/:num are cached, which can lead to a 5x improvement of speed for this API endpoint. 00e92054caba9689c0f8ed913240668039b6e8de

    Ryan Bigg

* Cached variant objects which can lead to slightly faster loading times (4x) for each variant.

    Ryan Bigg

* Added a route to allow for /api/variants/:id requests

    Ryan Bigg

* Taxons can now be gathered without their children with the `?without_children=1` query parameter. #4112

    Ryan Bigg

* Orders on the `/api/orders/mine` endpoint can now be paginated and searched. #4099

    Richard Nuno

