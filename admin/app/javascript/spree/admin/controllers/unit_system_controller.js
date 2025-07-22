import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "weightUnit"]

  unitSystemHandler(){
    let unitSystemByMeasurement = {
      "metric": [
        ["Kilogram (kg)", "kg"],
        ["Gram (g)", "g"],
      ],
      "imperial": [
        ["Pound (lb)", "lb"],
        ["Ounce (oz)", "oz"]
      ]
    }
    let unitSystem = this.bodyTarget.value
    let weightUnits = unitSystemByMeasurement[unitSystem]
    let reqUnits = "";

    weightUnits.forEach((unit) => {
      reqUnits += "<option value=" + unit[1] + ">" + unit[0] + "</option>";
    })

    this.weightUnitTarget.innerHTML = reqUnits
  }
}