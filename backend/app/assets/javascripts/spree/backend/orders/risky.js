var riskyOrderCount = 0;
var totalRiskyOrders;

$(document).ready(function(){
  loadRiskyOrder();
  $("#progress").fadeIn();
});

$(document).on('click', '.js-risky-next', function() {
  nextRiskyOrder();
});

$(document).on('click', '.js-risky-prev', function() {
  prevRiskyOrder();
});

$(document).on('click', '.js-risky-cancel', function() {
  cancelRiskyOrder();
});

$(document).on('click', '.js-risky-approve', function() {
  approveRiskyOrder();
});
$(document).on('click', '.js-view-risky-order', function() {
  viewRiskyOrder($(this));
});

function cancelRiskyOrder(){
  $.ajax({
    type: 'PUT',
    url: Spree.routes.orders_api + "/" + getOrderNumber() + '/cancel'
  }).done(function (data) {
    processCancelledOrder();
  }).error(function (msg) {
    console.log(msg);
  });
}

function approveRiskyOrder(){
  $.ajax({
    type: 'PUT',
    url: Spree.routes.orders_api + "/" + getOrderNumber() + '/approve'
  }).done(function (data) {
    processApprovedOrder();
  }).error(function (msg) {
    console.log(msg);
  });
}

function processCancelledOrder(){
  removeOrderFromTable();
  loadRiskyOrder();
}

function processApprovedOrder(){
  removeOrderFromTable();
  loadRiskyOrder();
}

function removeOrderFromTable(){
  var deletedOrder = $('table#listing_risky_orders tbody tr:eq(' + riskyOrderCount + ')');

  deletedOrder.slideUp();
  deletedOrder.remove();
}

function loadRiskyOrder(){
  // totalRiskyOrders calculated here because after every cancel the
  // totalRiskyOrders should be calculated again
  totalRiskyOrders = $('table#listing_risky_orders tbody tr').length-1;

  $.ajax({
    type: 'GET',
    url: '/admin/orders/' + getOrderNumber() + '/risky_order_info'
  }).done(function (data) {
    setRiskyOrder(data);
  }).error(function (msg) {
    console.log(msg);
  });
}

function setRiskyOrder(data){
  $('.js-risky-order-info').html(data);
  $('table#listing_risky_orders tbody tr').removeClass("success");
  $('table#listing_risky_orders tbody tr:eq(' + riskyOrderCount + ')').addClass("success");

  if(riskyOrderCount == 0){
    $(".js-risky-next").show();
  } else if (riskyOrderCount == totalRiskyOrders) {
    $(".js-risky-prev").show();
  } else {
    $(".js-risky-next").show();
    $(".js-risky-prev").show();
  }
}

function nextRiskyOrder(){
  riskyOrderCount++;
  loadRiskyOrder();
}

function prevRiskyOrder(){
  riskyOrderCount--;
  loadRiskyOrder();
}

function viewRiskyOrder(clicked_element){
  riskyOrderCount = clicked_element.parents("tr").index();
  loadRiskyOrder();
}

function getOrderNumber(){
  return $('table#listing_risky_orders tbody tr:eq(' + riskyOrderCount + ')').data('order-number');
}
