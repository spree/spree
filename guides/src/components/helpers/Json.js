// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import Highlight, { defaultProps } from 'prism-react-renderer'
import * as R from 'ramda'

// --- Utils
import DATA_SAMPLES from '../../data'

/**
 * Component
 */

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
        <Highlight
          {...defaultProps}
          theme=""
          code={this.normalizeJson(this.props.sample, this.props.merge)}
          language="json"
        >
          {({ className, style, tokens, getLineProps, getTokenProps }) => (
            <pre className={className}>
              {tokens.map((line, i) => (
                <div {...getLineProps({ line, key: i })}>
                  {line.map((token, key) => (
                    <span {...getTokenProps({ token, key })} />
                  ))}
                </div>
              ))}
            </pre>
          )}
        </Highlight>
      </div>
    )
  }
}
