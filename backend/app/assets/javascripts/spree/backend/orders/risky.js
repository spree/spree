var activeRiskyOrder = 0;
var totalRiskyOrders;

$(document).ready(loadRiskyOrder);

$(document).on('click', '.js-risky-next', nextRiskyOrder);
$(document).on('click', '.js-risky-prev', prevRiskyOrder);
$(document).on('click', '.js-risky-cancel', cancelRiskyOrder);
$(document).on('click', '.js-risky-approve', approveRiskyOrder);
$(document).on('click', '.js-view-risky-order', function() {
  viewRiskyOrder($(this));
});

function cancelRiskyOrder(){
  var url = Spree.routes.orders_api + '/' + getOrderNumber() + '/cancel';
  riskyAjaxActionHandler(url);
}

function approveRiskyOrder(){
  var url = Spree.routes.orders_api + '/' + getOrderNumber() + '/approve';
  riskyAjaxActionHandler(url);
}

function riskyAjaxActionHandler(url){
  $.ajax({
    type: 'PUT',
    url: url
  }).done(function () {
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

  if(totalRiskyOrders >= 0){
    $.ajax({
      type: 'GET',
      url: '/admin/orders/' + getOrderNumber() + '/risky_order_info'
    }).done(function (data) {
      setRiskyOrder(data);
    }).error(function (msg) {
      console.log(msg);
    });
  } else {
    noRiskyOrdersFound();
  }
}

function setRiskyOrder(data){
  $('.js-risky-order-info').html(data);
  // remove the success class from every tr
  $('table#listing_risky_orders tbody tr').removeClass('info');
  // assign the class to the current active tr
  $('table#listing_risky_orders tbody tr:eq(' + activeRiskyOrder + ')').addClass('info');

  if(!(totalRiskyOrders === 0)){
    if(activeRiskyOrder === 0){
      showRiskyNav('next');
    } else if (activeRiskyOrder == totalRiskyOrders) {
      showRiskyNav('prev');
    } else {
      showRiskyNav('next');
      showRiskyNav('prev');
    }
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

function viewRiskyOrder(clickedElement){
  activeRiskyOrder = clickedElement.parents('tr').index();
  loadRiskyOrder();
}

function showRiskyNav(type){
  // Need to use .css() here instead of .show()
  // We want the element to be inline block instead of inline
  $('.js-risky-' + type).css('display', 'inline-block');
}

function getOrderNumber(){
  return $('table#listing_risky_orders tbody tr:eq(' + activeRiskyOrder + ')').data('order-number');
}

function noRiskyOrdersFound(){
  var alertNoRiskyFound = '<div class="alert alert-success">No risky orders found</div>';

  $('.js-risky-order-info').html('');
  $(alertNoRiskyFound).insertAfter('table#listing_risky_orders');
  $('table#listing_risky_orders').remove();
}
