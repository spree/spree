import { cookies } from 'next/headers'
import { type CartRef, createCart } from './checkout'

const COOKIE = 'spree_cart'

export async function currentCart(): Promise<CartRef | null> {
  const value = (await cookies()).get(COOKIE)?.value
  if (!value) return null
  try {
    return JSON.parse(value) as CartRef
  } catch {
    return null
  }
}

export async function cartForWriting(): Promise<CartRef> {
  const existing = await currentCart()
  if (existing) return existing
  const cart = await createCart()
  ;(await cookies()).set(COOKIE, JSON.stringify(cart), { httpOnly: true, path: '/' })
  return cart
}

export async function forgetCart() {
  ;(await cookies()).delete(COOKIE)
}
