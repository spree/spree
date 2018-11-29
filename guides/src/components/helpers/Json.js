import * as React from 'react'
import PropTypes from 'prop-types'
import { PrismAsyncLight as SyntaxHighlighter } from 'react-syntax-highlighter'
import syntaxTheme from 'react-syntax-highlighter/dist/esm/styles/prism/tomorrow'
import * as R from 'ramda'

import DATA_SAMPLES from '../../data'

export default class Json extends React.Component {
  static propTypes = {
    sample: PropTypes.oneOf(Object.keys(DATA_SAMPLES)),
    merge: PropTypes.string
  }

  normalizeJson = (sample, merge) => {
    let json = DATA_SAMPLES[this.props.sample]

    if (!R.isNil(merge)) {
      json = R.merge(json, JSON.parse(merge))
    } else {
      json = DATA_SAMPLES[this.props.sample]
    }

    return JSON.stringify(json, null, 2)
  }

  render() {
    return (
      <div>
        <SyntaxHighlighter language="json" style={syntaxTheme}>
          {this.normalizeJson(this.props.sample, this.props.merge)}
        </SyntaxHighlighter>
      </div>
    )
  }
}
