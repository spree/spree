import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "container",
    "filtersContainer",
    "groupsContainer",
    "hiddenInput",
    "filterTemplate",
    "groupTemplate",
    "combinatorButton",
    "combinatorLabel",
    "form"
  ]

  static values = {
    fields: Array,
    operators: Array
  }

  connect() {
    this.rootCombinator = "and"
    this.loadState()
  }

  // Called before form submission to add ransack params
  submitForm(event) {
    const form = this.hasFormTarget ? this.formTarget : event.target.closest("form")
    if (form) {
      this.generateRansackInputs(form)
    }
  }

  loadState() {
    const stateJson = this.hiddenInputTarget.value
    if (stateJson && stateJson !== "{}") {
      try {
        const state = JSON.parse(stateJson)
        this.renderState(state)
      } catch (e) {
        console.error("Failed to parse query state:", e)
      }
    }
  }

  renderState(state) {
    // Set root combinator
    if (state.combinator) {
      this.rootCombinator = state.combinator
      this.updateCombinatorDisplay()
    }

    // Render filters
    if (state.filters && state.filters.length > 0) {
      state.filters.forEach(filter => {
        this.addFilterWithData(filter, this.filtersContainerTarget)
      })
    }

    // Render groups
    if (state.groups && state.groups.length > 0) {
      state.groups.forEach(group => {
        this.addGroupWithData(group)
      })
    }
  }

  addFilter(event) {
    event.preventDefault()
    this.addFilterWithData({}, this.filtersContainerTarget)
    this.updateHiddenInput()
  }

  addFilterToGroup(event) {
    event.preventDefault()
    const groupEl = event.target.closest("[data-group-id]")
    const filtersContainer = groupEl.querySelector("[data-group-filters-container]")
    this.addFilterWithData({}, filtersContainer)
    this.updateHiddenInput()
  }

  addFilterWithData(filterData, container) {
    const template = this.filterTemplateTarget.content.cloneNode(true)
    const row = template.querySelector("[data-filter-id]")
    row.dataset.filterId = filterData.id || this.generateId()

    // Populate field options
    const fieldSelect = row.querySelector("[data-field-select]")
    this.fieldsValue.forEach(field => {
      const option = document.createElement("option")
      option.value = field.key
      option.textContent = field.label
      if (filterData.field === field.key) {
        option.selected = true
      }
      fieldSelect.appendChild(option)
    })

    // If we have a field selected, update operators and value
    if (filterData.field) {
      const fieldConfig = this.fieldsValue.find(f => f.key === filterData.field)
      if (fieldConfig) {
        this.updateOperatorOptions(row, fieldConfig.operators, filterData.operator)
        this.updateValueInput(row, fieldConfig, filterData.value, filterData.operator)
      }
    }

    container.appendChild(row)
  }

  addOrGroup(event) {
    event.preventDefault()
    this.addGroupWithData({ combinator: "or", filters: [], groups: [] })
    this.updateHiddenInput()
  }

  addGroupWithData(groupData) {
    const template = this.groupTemplateTarget.content.cloneNode(true)
    const group = template.querySelector("[data-group-id]")
    group.dataset.groupId = groupData.id || this.generateId()
    group.dataset.combinator = groupData.combinator || "or"

    // Update combinator label
    const label = group.querySelector("[data-group-combinator-label]")
    if (label) {
      label.textContent = (groupData.combinator || "or").toUpperCase()
    }

    // Add existing filters to the group
    if (groupData.filters && groupData.filters.length > 0) {
      const filtersContainer = group.querySelector("[data-group-filters-container]")
      groupData.filters.forEach(filter => {
        this.addFilterWithData(filter, filtersContainer)
      })
    }

    this.groupsContainerTarget.appendChild(group)
  }

  removeFilter(event) {
    event.preventDefault()
    const filterRow = event.target.closest("[data-filter-id]")
    if (filterRow) {
      filterRow.remove()
      this.updateHiddenInput()
    }
  }

  removeGroup(event) {
    event.preventDefault()
    const group = event.target.closest("[data-group-id]")
    if (group) {
      group.remove()
      this.updateHiddenInput()
    }
  }

  toggleCombinator(event) {
    event.preventDefault()
    this.rootCombinator = this.rootCombinator === "and" ? "or" : "and"
    this.updateCombinatorDisplay()
    this.updateHiddenInput()
  }

  toggleGroupCombinator(event) {
    event.preventDefault()
    const group = event.target.closest("[data-group-id]")
    const currentCombinator = group.dataset.combinator
    const newCombinator = currentCombinator === "and" ? "or" : "and"

    group.dataset.combinator = newCombinator
    const label = group.querySelector("[data-group-combinator-label]")
    if (label) {
      label.textContent = newCombinator.toUpperCase()
    }

    this.updateHiddenInput()
  }

  updateCombinatorDisplay() {
    if (this.hasCombinatorLabelTarget) {
      this.combinatorLabelTarget.textContent = this.rootCombinator.toUpperCase()
    }
  }

  onFieldChange(event) {
    const filterRow = event.target.closest("[data-filter-id]")
    const field = event.target.value
    const fieldConfig = this.fieldsValue.find(f => f.key === field)

    if (fieldConfig) {
      this.updateOperatorOptions(filterRow, fieldConfig.operators)
      const operator = filterRow.querySelector("[data-operator-select]")?.value
      this.updateValueInput(filterRow, fieldConfig, null, operator)
    }

    this.updateHiddenInput()
  }

  onOperatorChange(event) {
    const filterRow = event.target.closest("[data-filter-id]")
    const operator = event.target.value
    const noValueOperators = ["null", "not_null"]

    const valueContainer = filterRow.querySelector("[data-value-container]")
    if (noValueOperators.includes(operator)) {
      valueContainer.style.display = "none"
    } else {
      valueContainer.style.display = ""
      // Rebuild value input when switching between single/multi operators
      const field = filterRow.querySelector("[data-field-select]")?.value
      const fieldConfig = this.fieldsValue.find(f => f.key === field)
      if (fieldConfig && (fieldConfig.type === "select" || fieldConfig.type === "status")) {
        this.updateValueInput(filterRow, fieldConfig, null, operator)
      }
    }

    this.updateHiddenInput()
  }

  onValueChange() {
    this.updateHiddenInput()
  }

  updateOperatorOptions(filterRow, operators, selectedOperator = null) {
    const operatorSelect = filterRow.querySelector("[data-operator-select]")
    operatorSelect.innerHTML = ""

    const operatorLabels = {
      eq: "equals",
      not_eq: "does not equal",
      cont: "contains",
      not_cont: "does not contain",
      start: "starts with",
      end: "ends with",
      gt: "greater than",
      gteq: "greater than or equal",
      lt: "less than",
      lteq: "less than or equal",
      in: "is any of",
      not_in: "is none of",
      null: "is empty",
      not_null: "is not empty"
    }

    operators.forEach(op => {
      const option = document.createElement("option")
      option.value = op
      option.textContent = operatorLabels[op] || op
      if (selectedOperator === op) {
        option.selected = true
      }
      operatorSelect.appendChild(option)
    })
  }

  updateValueInput(filterRow, fieldConfig, existingValue = null, operator = null) {
    const valueContainer = filterRow.querySelector("[data-value-container]")
    valueContainer.innerHTML = ""

    // Check if operator requires multi-select
    const isMultiOperator = ["in", "not_in"].includes(operator)

    let input
    switch (fieldConfig.type) {
      case "date":
        input = document.createElement("input")
        input.type = "date"
        input.className = "form-input text-sm"
        break
      case "datetime":
        input = document.createElement("input")
        input.type = "datetime-local"
        input.className = "form-input text-sm"
        break
      case "number":
      case "currency":
        input = document.createElement("input")
        input.type = "number"
        input.className = "form-input text-sm"
        input.step = fieldConfig.type === "currency" ? "0.01" : "1"
        break
      case "boolean":
        input = document.createElement("select")
        input.className = "form-select text-sm"
        input.innerHTML = `
          <option value="true">Yes</option>
          <option value="false">No</option>
        `
        break
      case "status":
      case "select":
        // For in/not_in operators, use multi-select with tom-select
        if (isMultiOperator) {
          const wrapper = document.createElement("div")
          wrapper.className = "w-full"
          wrapper.dataset.controller = "select"
          wrapper.dataset.selectMultipleValue = "true"

          // Build options array for tom-select
          const selectOptions = []
          if (fieldConfig.value_options) {
            fieldConfig.value_options.forEach(opt => {
              selectOptions.push({
                id: opt.value || opt,
                name: opt.label || opt
              })
            })
          }
          wrapper.dataset.selectOptionsValue = JSON.stringify(selectOptions)

          input = document.createElement("select")
          input.className = "form-select text-sm"
          input.multiple = true
          input.dataset.selectTarget = "input"
          input.dataset.valueInput = ""

          // Restore existing values for multi-select
          if (existingValue !== null && existingValue !== undefined && Array.isArray(existingValue)) {
            const selectedIds = existingValue.map(item => {
              if (typeof item === 'object') {
                return item.id
              } else {
                return item
              }
            })
            wrapper.dataset.selectActiveOptionValue = JSON.stringify(selectedIds)
          }

          input.dataset.action = "change->query-builder#onValueChange"
          wrapper.appendChild(input)
          valueContainer.appendChild(wrapper)
          return // Early return since we already appended
        } else {
          // Single select for eq/not_eq operators
          input = document.createElement("select")
          input.className = "form-select text-sm"
          input.innerHTML = '<option value="">Select...</option>'
          if (fieldConfig.value_options) {
            fieldConfig.value_options.forEach(opt => {
              const option = document.createElement("option")
              option.value = opt.value || opt
              option.textContent = opt.label || opt
              input.appendChild(option)
            })
          }
        }
        break
      case "autocomplete":
        // Create a wrapper div with select controller
        const wrapper = document.createElement("div")
        wrapper.className = "w-full"
        wrapper.dataset.controller = "select"
        wrapper.dataset.selectMultipleValue = "true"

        if (fieldConfig.search_url) {
          wrapper.dataset.selectUrlValue = fieldConfig.search_url
          // Use remote search mode so it doesn't pre-fetch and overwrite our preloaded options
          wrapper.dataset.selectRemoteSearchValue = "true"
        }

        // Use name as value field for tags (tags_name ransack attribute expects tag names)
        const useNameAsValue = fieldConfig.key && fieldConfig.key.includes("name")
        if (useNameAsValue) {
          wrapper.dataset.selectValueFieldValue = "name"
        }

        input = document.createElement("select")
        input.className = "form-select text-sm"
        input.multiple = true
        input.dataset.selectTarget = "input"
        input.dataset.valueInput = "" // Mark as value input for serialization

        // Restore existing values - we store as array of {id, name} objects
        // Use remoteSearchActiveOption which properly preloads options and selects them
        if (existingValue !== null && existingValue !== undefined && Array.isArray(existingValue) && existingValue.length > 0) {
          const preloadedOptions = existingValue.map(item => {
            if (typeof item === 'object') {
              return { id: useNameAsValue ? item.name : item.id, name: item.name }
            } else {
              return { id: item, name: item }
            }
          })
          wrapper.dataset.selectRemoteSearchActiveOptionValue = JSON.stringify(preloadedOptions)
        }

        // Set up change listener on select element directly
        input.dataset.action = "change->query-builder#onValueChange"

        wrapper.appendChild(input)
        valueContainer.appendChild(wrapper)

        return // Early return since we already appended
      default:
        input = document.createElement("input")
        input.type = "text"
        input.className = "form-input text-sm"
        input.placeholder = "Enter value..."
    }

    input.dataset.valueInput = ""
    input.dataset.action = "input->query-builder#onValueChange change->query-builder#onValueChange"

    if (existingValue !== null && existingValue !== undefined) {
      input.value = existingValue
    }

    valueContainer.appendChild(input)
  }

  clear(event) {
    event.preventDefault()
    this.filtersContainerTarget.innerHTML = ""
    this.groupsContainerTarget.innerHTML = ""
    this.rootCombinator = "and"
    this.updateCombinatorDisplay()
    this.updateHiddenInput()
  }

  updateHiddenInput() {
    const state = this.serializeState()
    this.hiddenInputTarget.value = JSON.stringify(state)
  }

  serializeState() {
    const filters = this.serializeFilters(this.filtersContainerTarget)
    const groups = this.serializeGroups()

    return {
      id: "root",
      combinator: this.rootCombinator,
      filters: filters,
      groups: groups
    }
  }

  serializeFilters(container) {
    const filters = []
    container.querySelectorAll(":scope > [data-filter-id]").forEach(row => {
      // Handle multi-select (tom-select) values
      const valueInput = row.querySelector("[data-value-input]")
      let value = null

      if (valueInput) {
        if (valueInput.multiple) {
          // Get all selected options for multi-select
          // Store as objects with id and name for autocomplete restoration
          value = Array.from(valueInput.selectedOptions).map(opt => ({
            id: opt.value,
            name: opt.textContent
          }))
        } else {
          value = valueInput.value
        }
      }

      const filter = {
        id: row.dataset.filterId,
        field: row.querySelector("[data-field-select]")?.value,
        operator: row.querySelector("[data-operator-select]")?.value,
        value: value
      }
      if (filter.field) {
        filters.push(filter)
      }
    })
    return filters
  }

  serializeGroups() {
    const groups = []
    this.groupsContainerTarget.querySelectorAll(":scope > [data-group-id]").forEach(groupEl => {
      const filtersContainer = groupEl.querySelector("[data-group-filters-container]")
      const group = {
        id: groupEl.dataset.groupId,
        combinator: groupEl.dataset.combinator || "or",
        filters: this.serializeFilters(filtersContainer),
        groups: []
      }
      groups.push(group)
    })
    return groups
  }

  generateId() {
    return Math.random().toString(36).substring(2, 10)
  }

  // Generate ransack params from filters and add as hidden inputs to form
  generateRansackInputs(form) {
    // Remove any existing ransack inputs we've added
    form.querySelectorAll("[data-ransack-input]").forEach(el => el.remove())

    const state = this.serializeState()
    const ransackParams = this.stateToRansackParams(state)

    // Add hidden inputs for each ransack param
    Object.entries(ransackParams).forEach(([key, value]) => {
      if (Array.isArray(value)) {
        // For array values (like _in predicates), add multiple inputs with same name
        value.forEach(v => {
          const input = document.createElement("input")
          input.type = "hidden"
          input.name = `q[${key}][]`
          input.value = v
          input.dataset.ransackInput = ""
          form.appendChild(input)
        })
      } else {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = `q[${key}]`
        input.value = value
        input.dataset.ransackInput = ""
        form.appendChild(input)
      }
    })
  }

  // Convert state object to ransack params object
  stateToRansackParams(state) {
    const params = {}
    const combinator = state.combinator || "and"

    // For "and" combinator, each filter becomes a separate ransack param
    // For "or" combinator, we need to use ransack's grouping (more complex)
    // For simplicity, we'll handle "and" directly and "or" with groupings

    if (combinator === "and") {
      // Simple case: all filters are ANDed together
      state.filters.forEach(filter => {
        const ransackParam = this.filterToRansackParam(filter)
        Object.assign(params, ransackParam)
      })

      // Handle groups (OR groups within AND root)
      state.groups.forEach((group, idx) => {
        const groupParams = this.groupToRansackParams(group, idx)
        Object.assign(params, groupParams)
      })
    } else {
      // OR at root level - use grouping syntax
      // ransack uses: { g: { '0' => { m: 'or', c: { '0' => {...}, '1' => {...} } } } }
      // This is complex, so for MVP we'll just OR the filters
      const groupKey = `g[0]`
      params[`${groupKey}[m]`] = "or"
      state.filters.forEach((filter, idx) => {
        const filterParams = this.filterToRansackParam(filter)
        Object.entries(filterParams).forEach(([key, value]) => {
          params[`${groupKey}[c][${idx}][${key}]`] = value
        })
      })
    }

    return params
  }

  // Convert a single filter to ransack param
  filterToRansackParam(filter) {
    if (!filter.field || !filter.operator) return {}

    const operatorMap = {
      eq: "_eq",
      not_eq: "_not_eq",
      cont: "_cont",
      not_cont: "_not_cont",
      start: "_start",
      end: "_end",
      gt: "_gt",
      gteq: "_gteq",
      lt: "_lt",
      lteq: "_lteq",
      in: "_in",
      not_in: "_not_in",
      null: "_null",
      not_null: "_not_null"
    }

    const predicate = operatorMap[filter.operator] || "_eq"
    const paramName = filter.field + predicate

    // Handle null/not_null which don't need values
    if (filter.operator === "null" || filter.operator === "not_null") {
      return { [paramName]: true }
    }

    // Extract values from autocomplete objects
    let value = filter.value
    if (Array.isArray(value) && value.length > 0 && typeof value[0] === 'object') {
      // For autocomplete values, extract just the IDs
      value = value.map(item => item.id)
    }

    return { [paramName]: value }
  }

  // Convert a group to ransack params using grouping syntax
  groupToRansackParams(group, groupIdx) {
    const params = {}
    const groupKey = `g[${groupIdx}]`
    params[`${groupKey}[m]`] = group.combinator || "or"

    group.filters.forEach((filter, filterIdx) => {
      const filterParams = this.filterToRansackParam(filter)
      Object.entries(filterParams).forEach(([key, value]) => {
        if (Array.isArray(value)) {
          value.forEach((v, vIdx) => {
            params[`${groupKey}[c][${filterIdx}][${key}][]`] = v
          })
        } else {
          params[`${groupKey}[c][${filterIdx}][${key}]`] = value
        }
      })
    })

    return params
  }
}
