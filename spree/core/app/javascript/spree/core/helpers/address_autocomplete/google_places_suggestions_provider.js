export default class {
  async connect() {
    if (typeof google?.maps === 'undefined') {
      console.error('Google Places API is not loaded')
      return
    }
    this.placesApi = await google.maps.importLibrary('places')
    this.googleSessionToken = new this.placesApi.AutocompleteSessionToken()
  }

  async getSuggestions(input, country) {
    if (this.placesApi === undefined) {
      throw new Error('You must call connect() before getSuggestions()')
    }

    const request = {
      input,
      // We can use `address`, `street_address`
      // `street_address` is the most accurate and specific, but sometimes it returns no results, even if the address is valid
      // Since we are validating the address on the server, we can use `address`
      includedRegionCodes: [country],
      sessionToken: this.googleSessionToken
    }

    try {
      const response = await this.placesApi.AutocompleteSuggestion.fetchAutocompleteSuggestions(request)
      return response.suggestions.map((element, index) => this.parsePrediction(element.placePrediction, index))
    } catch (error) {
      console.error('Error fetching autocomplete suggestions', error)
      return []
    }
  }

  async getPlaceDetails(placeID) {
    if (this.placesApi === undefined) {
      throw new Error('You must call connect() before getPlaceDetails()')
    }

    try {
      const service = new this.placesApi.Place({ id: placeID })

      const { place } = await service.fetchFields({ fields: ["addressComponents"] })

      const fullAddress = []
      let hasStreetNumber = false

      const details = {
        fullAddress: '',
        city: '',
        stateAbbr: '',
        zipcode: '',
        hasStreetNumber: false
      }

      let locality, postal_town, sublocality, administrative_area_level_3, premise, subpremise

      place.addressComponents.forEach((component) => {
        if (component.types.includes('street_number')) {
          fullAddress.push(component.longText)
          hasStreetNumber = true
        }
        if (component.types.includes('subpremise')) {
          subpremise = component.longText
        }
        if (component.types.includes('premise')) {
          premise = component.longText
        }
        if (component.types.includes('route')) {
          fullAddress.push(component.longText)
        }
        if (component.types.includes('locality')) {
          locality = component.longText
        }
        if (component.types.includes('postal_town')) {
          postal_town = component.longText
        }
        if (component.types.includes('sublocality')) {
          sublocality = component.longText
        }
        if (component.types.includes('administrative_area_level_1')) {
          details.stateAbbr = component.shortText
        }
        if (component.types.includes('postal_code')) {
          details.zipcode = component.longText
        }
        if (component.types.includes('administrative_area_level_3')) {
          administrative_area_level_3 = component.longText
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
      return details
    } catch (error) {
      console.error('Error fetching autocomplete details', error)
      return null
    }
  }

  parsePrediction(prediction, index) {
    const suggestion = {
      index: index,
      placeID: prediction.placeId,
      description: prediction.text.text
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
    const description = prediction.text.text;
    let markedAreas = prediction.text.matches
      .map(({ startOffset, endOffset }) => ({
        offset: startOffset,
        length: endOffset - startOffset
      }))
      .sort((a, b) => a.offset - b.offset);
    const textAreas = []
    for (let i = 0; i < description.length; i++) {
      if (markedAreas[0]?.offset === i) {
        textAreas.push({
          text: description.substring(i, i + markedAreas[0].length),
          marked: true
        })
        i += markedAreas[0].length - 1
        markedAreas.shift()
        markedAreas = [...markedAreas.sort((m) => m.offset)]
      } else {
        textAreas.push({
          text: description.charAt(i),
          marked: false
        })
      }
    }

    return textAreas
  }
}
