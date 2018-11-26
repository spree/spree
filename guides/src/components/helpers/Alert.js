import * as React from 'react'
import PropTypes from 'prop-types'
import { cx } from 'emotion'

import IconAlert from 'react-feather/dist/icons/alert-circle'
import IconNote from 'react-feather/dist/icons/file-text'

import renderHtml from '../../utils/renderHtml'

export default class Alert extends React.Component {
  static propTypes = {
    type: PropTypes.oneOf(['admin_only']),
    kind: PropTypes.oneOf(['danger', 'warning', 'info', 'note']),
    children: PropTypes.array
  }

  __messages = {
    admin_only: 'This action is only accessible by an admin user.'
  }

  __classes = {
    danger: 'bg-washed-red b--red dark-red',
    note: 'bg-washed-yellow b--gold gray'
  }

  __iconClasses = {
    base: 'ba mr2 pa2 bg-white br-100 absolute left--1 top--1',
    note: 'b--gold'
  }

  getIconClasses = kind => {
    return cx(this.__iconClasses['base'], this.__iconClasses[kind])
  }

  __icons = {
    danger: <IconAlert className={this.getIconClasses('danger')} />,
    note: <IconNote className={this.getIconClasses('note')} />
  }

  render() {
    const { type, kind, children } = this.props
    return (
      <div
        className={cx(
          this.__classes[kind],
          'mt4 flex items-center ba pl4 pr3 pv3 br2 fw6 relative'
        )}
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
            dangerouslySetInnerHTML={{ __html: renderHtml(children[0]) }}
          />
        )}
      </div>
    )
  }
}
