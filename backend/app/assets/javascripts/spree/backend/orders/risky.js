var activeRiskyOrder = 0;
var totalRiskyOrders;

$(document).ready(function(){
  loadRiskyOrder();
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
    processOrderActionSuccess();
  }).error(function (msg) {
    console.log(msg);
  });
}

function approveRiskyOrder(){
  $.ajax({
    type: 'PUT',
    url: Spree.routes.orders_api + "/" + getOrderNumber() + '/approve'
  }).done(function (data) {
    processOrderActionSuccess();
  }).error(function (msg) {
    console.log(msg);
  });
}

function processOrderActionSuccess(){
  removeOrderFromTable();
  loadRiskyOrder();
}

function removeOrderFromTable(){
  var deletedOrder = $('table#listing_risky_orders tbody tr:eq(' + activeRiskyOrder + ')');

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
  // remove the success class from every tr
  $('table#listing_risky_orders tbody tr').removeClass('info');
  // assign the class to the current active tr
  $('table#listing_risky_orders tbody tr:eq(' + activeRiskyOrder + ')').addClass('info');

  if(activeRiskyOrder == 0){
    showRiskyNav('next');
  } else if (activeRiskyOrder == totalRiskyOrders) {
    showRiskyNav('prev');
  } else {
    showRiskyNav('next');
    showRiskyNav('prev');
  }
}

function nextRiskyOrder(){
  activeRiskyOrder++;
  loadRiskyOrder();
}

function prevRiskyOrder(){
  activeRiskyOrder--;
  loadRiskyOrder();
}

function viewRiskyOrder(clicked_element){
  activeRiskyOrder = clicked_element.parents('tr').index();
  loadRiskyOrder();
}

function showRiskyNav(type){
  // need to use .css here, we want the element to be inline block instead of inline (.show())
  $('.js-risky-' + type).css('display', 'inline-block');
}

function getOrderNumber(){
  return $('table#listing_risky_orders tbody tr:eq(' + activeRiskyOrder + ')').data('order-number');
}
