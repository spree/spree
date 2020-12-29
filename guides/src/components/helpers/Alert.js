// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { cx } from 'emotion'

// --- Icons
import IconAlert from 'react-feather/dist/icons/alert-circle'
import IconNote from 'react-feather/dist/icons/file-text'
import IconWarning from 'react-feather/dist/icons/alert-triangle'

// --- Components
import Status from './Status'
import Json from './Json'

// --- Utils
import renderHtml from '../../utils/renderHtml'

/**
 * Component
 */

export default class Alert extends React.Component {
  static propTypes = {
    type: PropTypes.oneOf(['admin_only', 'not_found', 'authorization_failure']),
    kind: PropTypes.oneOf(['danger', 'warning', 'info', 'note']),
    children: PropTypes.array
  }

  __messages = {
    admin_only: 'This action is only accessible by an admin user.',
    not_found: (
      <React.Fragment>
        <Status code="404" />
        <Json sample="404" />
      </React.Fragment>
    ),
    authorization_failure: (
      <React.Fragment>
        <Status code="401" />
        <Json sample="401" />
      </React.Fragment>
    ),
    no_api_key: (
      <React.Fragment>
        <Status code="401" />
        <Json sample="no_api_key" />
      </React.Fragment>
    )
  }

  __classes = {
    danger: 'bg-washed-red b--light-red dark-red',
    note: 'bg-washed-yellow b--gold gray',
    warning: 'bg-washed-blue b--lightest-blue gray'
  }

  __iconClasses = {
    base: 'ba mr2 pa1 bg-white br3 absolute left--1 top--1',
    note: 'b--gold',
    warning: 'blue b--lightest-blue',
    danger: 'b--light-red light-red'
  }

  getIconClasses = kind => {
    return cx(this.__iconClasses['base'], this.__iconClasses[kind])
  }

  __icons = {
    danger: <IconAlert className={this.getIconClasses('danger')} />,
    note: <IconNote className={this.getIconClasses('note')} />,
    warning: <IconWarning className={this.getIconClasses('warning')} />
  }

  render() {
    const { type, kind, children } = this.props
    return (
      <div
        className={cx(this.__classes[kind], {
          'mv4 flex items-center ba pl4 pr3 pv3 br2 f5 fw5 relative': ![
            'authorization_failure',
            'not_found',
            'no_api_key'
          ].includes(type)
        })}
      >
        {this.__icons[kind]}
        {this.__messages[type]}
        {children && (
          <div
            className="lh-copy f5 fw5"
            css={{
              '& p': {
                margin: 0
              }
            }}
            dangerouslySetInnerHTML={{
              __html: renderHtml(children[0])
            }}
          />
        )}
      </div>
    )
  }
}
