import * as React from 'react'
import PropTypes from 'prop-types'

import STATUS from '../../data/status'

const Status = ({ code }) => (
  <div className="code flex w-100 items-center">
    <div className="dib ph3 pv2 bg-blue white br2 br--left ba b--blue ttu">
      Status:
    </div>
    <div className="blue ph3 pv2 bg-washed-blue flex-auto br2 br--right ba b--lightest-blue">
      {STATUS[code]}
    </div>
  </div>
)

Status.propTypes = {
  code: PropTypes.oneOf(Object.keys(STATUS))
}

export default Status
