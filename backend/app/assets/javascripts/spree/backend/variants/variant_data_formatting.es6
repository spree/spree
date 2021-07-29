/* eslint-disable no-unused-vars */

function buildVariantData (json) {
  if (json.data[0]) {
    json.data.forEach(variant => addIdToVariant(variant))
    json.data.forEach(variant => addImagesToVariants(variant, json.included))
    json.data.forEach(variant => addStockItems(variant, json.included))
    json.data.forEach(variant => addStockLocationToStockItem(variant.attributes.stock_items, json.included))
  } else {
    addIdToVariant(json.data)
    addImagesToVariants(json.data, json.included)
    addStockItems(json.data, json.included)
    addStockLocationToStockItem(json.data.attributes.stock_items, json.included)
  }

  return json.data
}

//
// Add ID to varaint
function addIdToVariant (variant) {
  variant.attributes.id = parseInt(variant.id, 10)
}

//
// Add image to varaint
function addImagesToVariants (variant, included) {
  if (variant.relationships.images.data[0] != null) {
    const attachedImageId = variant.relationships.images.data[0].id
    const imgPath = included.find((image) => image.type === 'image' && image.id === attachedImageId)

    if (imgPath != null) variant.attributes.image = imgPath.attributes.styles[2].url
  }
}

//
// Loop through variant -> stock_item relationships
function addStockItems (variant, included) {
  const stockItemsArray = []

  if (variant.relationships.stock_items != null) {
    const stockItems = variant.relationships.stock_items.data

    stockItems.forEach(function (si) {
      const stockItem = findStockItem(si.id, included)

      if (stockItem != null) stockItemsArray.push(stockItem)
    })
  }
  variant.attributes.stock_items = stockItemsArray
}

//
// Find appropriate stock item
function findStockItem (stockItemId, included) {
  const stockItem = included.find((stockItem) => stockItem.type === 'stock_item' && stockItem.id === stockItemId)

  return stockItem
}

//
// Loop through stock_item relationships and add
// stock_location details to stock_item.
function addStockLocationToStockItem (stockItems, included) {
  stockItems.forEach(function (si) {
    const stockLocationId = si.relationships.stock_location.data.id
    const stockLocation = findStockLocation(stockLocationId, included)

    if (stockLocation != null) {
      si.attributes.stock_location_id = stockLocation.id
      si.attributes.stock_location_name = stockLocation.attributes.name
    }
  })
}

//
// Find appropriate stock location
function findStockLocation (stockLocationId, included) {
  const stockLocation = included.find((stockLocation) => stockLocation.type === 'stock_location' && stockLocation.id === stockLocationId)

  return stockLocation
}
