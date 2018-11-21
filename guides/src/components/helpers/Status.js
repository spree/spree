import * as React from 'react'
import PropTypes from 'prop-types'

import STATUS from '../../data/status'

const Status = ({ code }) => (
  <pre>
    <code>Status: {STATUS[code]}</code>
  </pre>
)

Status.propTypes = {
  code: PropTypes.oneOf(Object.keys(STATUS))
}

export default Status
