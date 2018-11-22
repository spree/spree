import * as React from 'react'
import PropTypes from 'prop-types'
import { cx } from 'emotion'
import IconAlert from 'react-feather/dist/icons/alert-circle'

export default class Alert extends React.Component {
  static propTypes = {
    type: PropTypes.oneOf(['admin_only'])
  }

  __messages = {
    admin_only: 'This action is only accessible by an admin user.'
  }

  __classes = {
    admin_only: 'bg-washed-red b--red dark-red'
  }

  __iconClasses = 'mr2 pa1 bg-white br-100'

  __icons = {
    admin_only: <IconAlert className={this.__iconClasses} />
  }

  render() {
    return (
      <div
        className={cx(
          this.__classes[this.props.type],
          'flex items-center ba ph3 pv2 br2 fw6'
        )}
      >
        {this.__icons[this.props.type]}
        {this.__messages[this.props.type]}
      </div>
    )
  }
}
