// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import { last, equals } from 'ramda'

// --- Icons
import IconSplit from 'react-feather/dist/icons/chevron-right'

// --- Components
import Crumb from './Crumb'

/**
 * Helpers
 */

/**
 * @description Checks if the current breadcrumb is the last one in array
 * @param {object} currentCrumb
 * @param {array} allCrumbs
 * @returns {boolean}
 */
const isLast = (currentCrumb, allCrumbs) =>
  equals(currentCrumb, last(allCrumbs))

/**
 * Component
 */

const Breadcrumbs = ({ crumbs }) => (
  <nav className="bb b--light-gray pv3">
    <ul className="list ph4 mv0 flex items-center">
      {crumbs.map((crumb, index) => (
        <li className="flex items-center" key={index}>
          {crumb.url ? (
            <Link to={crumb.url}>
              <Crumb name={crumb.name} isActive={isLast(crumb, crumbs)} />
            </Link>
          ) : (
            <Crumb name={crumb.name} isActive={isLast(crumb, crumbs)} />
          )}
          {!isLast(crumb, crumbs) && <IconSplit className="moon-gray mr2" />}
        </li>
      ))}
    </ul>
  </nav>
)

Breadcrumbs.propTypes = {
  crumbs: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string.isRequired,
      url: PropTypes.string
    })
  ).isRequired
}

export default Breadcrumbs
