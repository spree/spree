export default class {
  async connect() {
    if (typeof google?.maps === 'undefined') {
      console.error('Google Maps API is not loaded')
      return
    }
    this.placesApi = await google.maps.importLibrary('places')
    this.googleSessionToken = new this.placesApi.AutocompleteSessionToken()
    this.autocompleteSevice = new this.placesApi.AutocompleteService()
  }

  async getSuggestions(input, country) {
    return new Promise((resolve, reject) => {
      if (this.placesApi === undefined) {
        reject('You must call connect() before getSuggestions()')
        return
      }

      this.autocompleteSevice.getPlacePredictions(
        {
          input,
          // We can use `address`, `street_address`
          // `street_address` is the most accurate and specific, but sometimes it returns no results, even if the address is valid
          // Since we are validating the address on the server, we can use `address`
          types: [],
          componentRestrictions: {
            country
          },
          sessionToken: this.googleSessionToken
        },
        (predictions, status) => {
          if (status !== this.placesApi.PlacesServiceStatus.OK) {
            resolve([])
          } else {
            resolve(predictions.map(this.parsePrediction.bind(this)))
          }
        }
      )
    })
  }

  async getPlaceDetails(placeID, target) {
    return new Promise((resolve, reject) => {
      if (this.placesApi === undefined) {
        reject('You must call connect() before getPlaceDetails()')
        return
      }

      const service = new this.placesApi.PlacesService(target)
      service.getDetails(
        {
          placeId: placeID,
          fields: ['address_components'],
          sessionToken: this.googleSessionToken
        },
        (place, status) => {
          if (status !== this.placesApi.PlacesServiceStatus.OK) {
            resolve(null)
            return
          }

          this.sessionToken = new this.placesApi.AutocompleteSessionToken()

          const fullAddress = []
          let hasStreetNumber = false

          const details = {
            fullAddress: '',
            city: '',
            stateAbbr: '',
            zipcode: '',
            hasStreetNumber: false
          }

          let locality = undefined
          let postal_town = undefined
          let sublocality = undefined
          let administrative_area_level_3 = undefined
          let premise = undefined
          let subpremise = undefined

          place.address_components.forEach((component) => {
            if (component.types.includes('street_number')) {
              fullAddress.push(component.long_name)
              hasStreetNumber = true
            }
            if (component.types.includes('subpremise')) {
              subpremise = component.long_name
            }
            if (component.types.includes('premise')) {
              premise = component.long_name
            }
            if (component.types.includes('route')) {
              fullAddress.push(component.long_name)
            }
            if (component.types.includes('locality')) {
              locality = component.long_name
            }
            if (component.types.includes('postal_town')) {
              postal_town = component.long_name
            }
            if (component.types.includes('sublocality')) {
              sublocality = component.long_name
            }
            if (component.types.includes('administrative_area_level_1')) {
              details.stateAbbr = component.short_name
            }
            if (component.types.includes('postal_code')) {
              details.zipcode = component.long_name
            }
            if (component.types.includes('administrative_area_level_3')) {
              administrative_area_level_3 = component.long_name
            }
          })
          // City is tricky, because it can be in different fields
          details.city =
            locality ||
            postal_town ||
            sublocality ||
            administrative_area_level_3 ||
            ''
          if (premise && !hasStreetNumber) {
            fullAddress.unshift(premise)
            hasStreetNumber = true
          }
          if (subpremise) {
            fullAddress.push(subpremise)
          }
          details.hasStreetNumber = hasStreetNumber
          details.fullAddress = fullAddress.join(' ')
          resolve(details)
        }
      )
    })
  }

  parsePrediction(prediction, index) {
    const suggestion = {
      index: index,
      placeID: prediction.place_id,
      description: prediction.description
    }

    const splittedText = this.splitTextForMarks(prediction)
    suggestion.html = splittedText
      .map((textArea) =>
        textArea.marked
          ? `<mark class="bg-transparent">${textArea.text}</mark>`
          : textArea.text
      )
      .join('')

    return suggestion
  }

  // This function takes the prediction and splits the description into an array of objects with the text and a boolean indicating if it should be highlighted
  splitTextForMarks(prediction) {
    let markedAreas = [...prediction.matched_substrings.sort((m) => m.offset)]
    const textAreas = []
    for (let i = 0; i < prediction.description.length; i++) {
      if (markedAreas[0]?.offset === i) {
        textAreas.push({
          text: prediction.description.substring(i, i + markedAreas[0].length),
          marked: true
        })
        i += markedAreas[0].length - 1
        markedAreas.shift()
        markedAreas = [...markedAreas.sort((m) => m.offset)]
      } else {
        textAreas.push({
          text: prediction.description.charAt(i),
          marked: false
        })
      }
    }

    return textAreas
  }
}
