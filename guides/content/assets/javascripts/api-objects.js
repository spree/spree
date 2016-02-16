window.onload = function() {

  // Polygon drawing
  function polygon(x, y, size, sides, rotate) {
    var self = this;

    self.centrePoint = [x,y];
    self.size = size;
    self.sides = sides;
    self.rotated = rotate;
    self.sizeMultiplier = 50;
    self.points = [];

    for (i = 0; i < sides; i++) {
      self.points.push([(
                       x +
                       (self.size * self.sizeMultiplier) *
                       (rotate ?
                          Math.sin(2 * 3.14159265 * i / sides) :
                          Math.cos(2 * 3.14159265 * i / sides)
                       )
                      ),
                      (
                       y +
                       (self.size * self.sizeMultiplier) *
                       (rotate ?
                         Math.cos(2 * 3.14159265 * i / sides) :
                         Math.sin(2 * 3.14159265 * i / sides)
                       )
                      )
                      ]);
    }

    self.svgString = 'M' + self.points.join(' ') + ' L Z';
  }

  // Canvas
  var canvas = new Raphael(document.getElementById('api-objects'), 960, 400);

  // Hexagon attributes on hover out & default state
  var h_attr_out = {
    stroke:         "#9FBBEA",
    "stroke-width": "2",
    fill:           "white",
    "fill-opacity": 0.2
  }

  // Hexagon attributes on hover in state
  var h_attr_in = {
    fill: "#78AD2F",
    "fill-opacity": '1',
    stroke: '#fff'
  }

  // Text attributes on hover out & default state
  var t_attr_out = {
    fill:           "white",
    "font-size":    "13px",
    "font-family":  "Source Code Pro",
    "fill-opacity": 0.5
  }

  // Text attributes on hover in state
  var t_attr_in = {
    "fill-opacity": 1
  }

  // Text on hover in animation
  var t_animate_in = function(this_object, hexagon_object) {
    hexagon_object.animate(h_attr_in, 200);
    this_object.animate(t_attr_in, 200);
  }

  // Text on hover out animation
  var t_animate_out = function(this_object, hexagon_object) {
    hexagon_object.animate(h_attr_out, 200);
    this_object.animate(t_attr_out, 200);
  }

  // Hexagon on hover in animation
  var h_animate_in = function(this_object, text_object) {
    this_object.animate(h_attr_in, 200);
    text_object.animate(t_attr_in, 200);
  }

  // Hexagon on hover out animation
  var h_animate_out = function(this_object, text_object) {
    this_object.animate(h_attr_out, 200);
    text_object.animate(t_attr_out, 200);
  }

  // API Hexagon object
  function h_object (id, pos_x, pos_y, href, t_object_id) {
    var self          = this;
    self.id           = id;
    self.pos_x        = pos_x;
    self.pos_y        = pos_y;
    self.href         = href;
    self.t_object_id  = t_object_id;

    var path = canvas.path(
                new polygon(self.pos_x, self.pos_y, 1.05, 6, 90).svgString
               );

    path.id = self.id;

    path.data("pos_x", self.pos_x);
    path.data("pos_y", self.pos_y);

    path.attr(h_attr_out);
    path.attr("href", self.href);

    path.hover(function(){
                 h_animate_in(path, canvas.getById(self.t_object_id))
               }, function(){
                 h_animate_out(path, canvas.getById(self.t_object_id))
               })
  }

  // API Hexagon Text object
  function t_object (id, text, h_object_id) {
    var self          = this;
    self.id           = id;
    self.text         = text;
    self.h_object_id  = h_object_id;
    self.pos_x        = canvas.getById(self.h_object_id).data("pos_x");
    self.pos_y        = canvas.getById(self.h_object_id).data("pos_y");

    var path = canvas.text(self.pos_x, self.pos_y, self.text)

    path.id = self.id;

    path.data("pos_x", self.pos_x);
    path.data("pos_y", self.pos_y);

    path.attr(t_attr_out)
    path.attr("href", canvas.getById(self.h_object_id).attr("href"))

    path.hover(function(){
                 t_animate_in(path, canvas.getById(self.h_object_id));
               }, function(){
                 t_animate_out(path, canvas.getById(self.h_object_id));
               })
  }

  // Creating api objects on canvas
  var line_items = new h_object("h_line_items", 57, 74, "line_items.html", "t_line_items")
  var line_items_text = new t_object("t_line_items", "LINE ITEMS", "h_line_items")

  var return_auth = new h_object("h_return_auth", 171, 74, "return_authorizations.html", "t_return_auth")
  var return_auth_text = new t_object("t_return_auth", "RETURN\nAUTHORI...", "h_return_auth")

  var orders = new h_object("h_orders", 57, 201, "orders.html", "t_orders")
  var orders_text = new t_object("t_orders", "ORDERS", "h_orders")

  var payments = new h_object("h_payments", 171, 200, "payments.html", "t_payments")
  var payments_text = new t_object("t_payments", "PAYMENTS", "h_payments")

  var shipments = new h_object("h_shipments", 57, 327, "shipments.html", "t_shipments")
  var shipments_text = new t_object("t_shipments", "SHIPMENTS", "h_shipments")

  var product_properties = new h_object("h_product_properties", 678, 200, "product_properties.html", "t_product_properties")
  var product_properties_text = new t_object("t_product_properties", "PRODUCT\nPROPERTIES", "h_product_properties")

  var variants = new h_object("h_variants", 792, 74, "variants.html", "t_variants")
  var variants_text = new t_object("t_variants", "VARIANTS", "h_variants")

  var images = new h_object("h_images", 906, 74, "#", "t_images")
  var images_text = new t_object("t_images", "IMAGES", "h_images")

  var products = new h_object("h_products", 792, 200, "products.html", "t_products")
  var products_text = new t_object("t_products", "PRODUCTS", "h_products")

  var taxons = new h_object("h_taxons", 792, 327, "#", "t_taxons")
  var taxons_text = new t_object("t_taxons", "TAXONS", "h_taxons")

  var taxonomies = new h_object("h_taxonomies", 906, 327, "taxonomies.html", "t_taxonomies")
  var taxonomies_text = new t_object("t_taxonomies", "TAXONOMIES", "h_taxonomies")

  var zones = new h_object("h_zones", 366, 327, "zones.html", "t_zones")
  var zones_text = new t_object("t_zones", "ZONES", "h_zones")

  var countries = new h_object("h_countries", 477, 327, "countries.html", "t_countries")
  var countries_text = new t_object("t_countries", "COUNTRIES", "h_countries")

  var addresses = new h_object("h_addresses", 590, 327, "addresses.html", "t_addresses")
  var addresses_text = new t_object("t_addresses", "ADDRESSES", "h_addresses")

}
