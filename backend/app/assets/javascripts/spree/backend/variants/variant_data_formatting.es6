// eslint-disable-next-line no-unused-vars
function formatDataForVariants (jsonDataItems) {
  jsonDataItems.forEach(item => addImagesToVariants(item))
  jsonDataItems.forEach(item => addStockLocationNameToStockItems(item))
  jsonDataItems.forEach(item => addAvailabiltyToStockItems(item))

  function addImagesToVariants (obj) {
    if (obj.type === 'variant' && obj.relationships.images.data[0]) {
      const attachedImageId = obj.relationships.images.data[0].id
      const imgPath = _.find(jsonDataItems, function (item) {
        return item.type === 'image' && item.id === attachedImageId
      })
      obj.attributes.image_path = imgPath.attributes.styles[2].url
    }
  }

  function addStockLocationNameToStockItems (obj) {
    if (obj.type === 'variant' && obj.relationships.stock_items.data) {
      const stockItems = obj.attributes.stock_items

      stockItems.forEach(function (si) {
        const stocklocationName = stockLocationName(si.stock_location_id, obj)
        si.stock_location_name = stocklocationName
      })
    }
  }

  function stockLocationName (stockLocationId, obj) {
    const allStockLocations = obj.attributes.stock_locations

    const stockLocation = allStockLocations.find((location) => {
      return location.id === stockLocationId
    })
    return stockLocation.name
  }

  function addAvailabiltyToStockItems (obj) {
    if (obj.type === 'variant' && obj.relationships.stock_items.data) {
      const stockItems = obj.attributes.stock_items

      stockItems.forEach(function (stockItem) {
        if (stockItem.count_on_hand > 0 || stockItem.backorderable === true) {
          stockItem.is_available = true
        } else {
          stockItem.is_available = false
        }
      })
    }
  }
}
