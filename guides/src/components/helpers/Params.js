// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import renderHtml from '../../utils/renderHtml'

/**
 * Component
 */

export default class Params extends React.Component {
  static propTypes = {
    params: PropTypes.string.isRequired
  }

  render() {
    const params = JSON.parse(this.props.params)
    return (
      <dl className="pa3 ba b--lightest-blue bg-washed-blue br2 gray">
        {params.map((param, index) => (
          <React.Fragment key={index}>
            <dt className="code fw4 dark-gray">{param.name}:</dt>
            <dd
              className="mb2 fw4"
              css={{
                '& p': {
                  margin: 0,
                  padding: 0
                }
              }}
              dangerouslySetInnerHTML={{
                __html: renderHtml(param.description)
              }}
            />
          </React.Fragment>
        ))}
      </dl>
    )
  }
}
