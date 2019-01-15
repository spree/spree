import * as React from 'react'
import PropTypes from 'prop-types'

import STATUS from '../../data/status'

const Status = ({ code }) => (
  <div className="code flex w-100 items-center">
    <div className="dib ph3 pv2 bg-spree-blue white ba b--spree-blue ttu">
      Status:
    </div>
    <div className="spree-blue ph3 pv2 bg-washed-blue flex-auto ba b--lightest-blue">
      {STATUS[code]}
    </div>
  </div>
)

Status.propTypes = {
  code: PropTypes.oneOf(Object.keys(STATUS))
}

export default Status
