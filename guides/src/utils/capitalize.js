import { join, juxt, compose, toUpper, head, tail } from 'ramda'

const capitalize = compose(
  join(''),
  juxt([
    compose(
      toUpper,
      head
    ),
    tail
  ])
)

export default capitalize
