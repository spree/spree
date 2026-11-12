import { type ClassValue, clsx } from 'clsx'
import { extendTailwindMerge } from 'tailwind-merge'

// Theme values tailwind-merge cannot know about. Unregistered, `rounded-card`
// and `shadow-card-lift` are treated as unknown classes, so a stock
// `rounded-lg` or `shadow-xs` beside them is never dropped and whichever comes
// later in the stylesheet silently wins.
const twMerge = extendTailwindMerge({
  extend: {
    theme: {
      radius: ['card'],
      shadow: ['card-lift', 'control', 'field-focus'],
    },
  },
})

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
