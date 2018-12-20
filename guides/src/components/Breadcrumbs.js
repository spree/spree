import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import { last, equals } from 'ramda'

import IconSplit from 'react-feather/dist/icons/chevron-right'

/**
 * @description Checks if the current breadcrumb is the last one in array
 * @param {object} currentCrumb
 * @param {array} allCrumbs
 * @returns {boolean}
 */
const isLast = (currentCrumb, allCrumbs) =>
  equals(currentCrumb, last(allCrumbs))

const Crumb = ({ name }) => (
  <span className="f4 fw5 dib mr2 spree-blue">{name}</span>
)

const Breadcrumbs = ({ crumbs }) => (
  <nav className="bb b--light-gray">
    <ul className="list ph4 flex items-center">
      {crumbs.map((crumb, index) => (
        <li className="flex items-center" key={index}>
          {isLast(crumb, crumbs) && <IconSplit className="moon-gray mr2" />}
          {crumb.url ? (
            <Link to={crumb.url}>
              <Crumb name={crumb.name} />
            </Link>
          ) : (
            <Crumb name={crumb.name} />
          )}
        </li>
      ))}
    </ul>
  </nav>
)

Crumb.propTypes = {
  name: PropTypes.string.isRequired
}

Breadcrumbs.propTypes = {
  crumbs: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string.isRequired,
      url: PropTypes.string
    })
  ).isRequired
}

export default Breadcrumbs
