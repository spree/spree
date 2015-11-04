var TaxonTreeNodesToSelect = [];
var TaxonTreeNotInList = [];

$(document).ready(function() {
  $('#input-search').on('keyup', function(e) {
    searchTree($(this).val());
  });

  $('form.js-product-taxon-tree-form').submit(function() {
    var selected = $('#tree').treeview('getSelected');
    var taxonIds = [];

    $.each(selected, function(index, node) {
      var taxonId = treeItemByNodeId(node.nodeId).data('taxonid');
      taxonIds.push(taxonId);
    });

    var newTaxonIds = taxonIds.concat(TaxonTreeNotInList);

    $('.js-product-taxon-ids').val(newTaxonIds);
  });
});

$(document).on('click', '.js-jump-to-hit', function() {
  var nodeId = $(this).data('nodeid');
  var $node = treeItemByNodeId(nodeId);

  $('html, body').animate({
    scrollTop: ($node.offset().top - 100),
  });
});

function displayNoTaxonsFound() {
  $('.js-tree-alert').text('No taxons found..');
  $('.js-tree-alert').addClass('alert-danger');
}

function displaySearchResultAlert(amount, term, firstHit) {
  var $infoAlert = $('.js-search-result-info');

  if (term) {
    $infoAlert.show();
    if (firstHit) {
      $infoAlert.html('<a href="javascript:;" data-nodeid="' + firstHit.nodeId + '" class="js-jump-to-hit">' + amount + ' results found</a>');
    } else {
      $infoAlert.text('No results found..');
    }
  } else {
    $infoAlert.hide();
  }
}

function treeItemByNodeId(nodeId) {
  return $('.list-group-item[data-nodeid="' + nodeId + '"]');
}

function treeNodeIdByTaxonId(taxonId) {
  var nodeId = $('.list-group-item[data-taxonid="' + taxonId + '"]').data('nodeid');
  console.log(nodeId);

  return nodeId;
}

function saveAsNodeToSelect(nodeId, taxonId) {
  if (typeof nodeId != 'undefined') {
    addToSelectedNodes(nodeId);
  } else {
    // we save the taxon_ids we couldnt find in a seperate array
    // these are from a different taxonomy but need to be saved later
    TaxonTreeNotInList.push(taxonId);
  }
}

function addToSelectedNodes(nodeId) {
  TaxonTreeNodesToSelect.push(nodeId);

  // filter out doubles
  TaxonTreeNodesToSelect = $.unique(TaxonTreeNodesToSelect);
}

function removeFromSelectedNodes(nodeId) {
  TaxonTreeNodesToSelect.splice($.inArray(nodeId, TaxonTreeNodesToSelect), 1);
}

function collapseAndReveal() {
  $('#tree').treeview('collapseAll', { silent: true });

  // reveal the selected nodes
  $('#tree').treeview('revealNode', [TaxonTreeNodesToSelect, { silent: true }]);
}

function searchTree(term) {
  collapseAndReveal();
  var results = $('#tree').treeview('search', [term, { ignoreCase: true, exactMatch: false }]);
  displaySearchResultAlert(results.length, term, results[0]);
}
