import * as React from 'react'

export default class DocSearch extends React.Component {
  state = {
    enabled: true
  }

  componentDidMount() {
    // Initialize Algolia search.
    if (window.docsearch) {
      window.docsearch({
        apiKey: 'fb697cd2d04591b036ea172259c05ba8',
        indexName: 'spreecommerce',
        inputSelector: '#algolia-doc-search'
      })
    } else {
      console.warn('Search has failed to load and now is being disabled')
      this.setState({ enabled: false })
    }
  }

  render() {
    const { enabled } = this.state

    return enabled ? (
      <form className="ml3">
        <input
          className="pa3 w6 br1 ba b--moon-gray"
          id="algolia-doc-search"
          type="search"
          placeholder="Search docs"
          aria-label="Search docs"
          size="50"
        />
      </form>
    ) : null
  }
}
