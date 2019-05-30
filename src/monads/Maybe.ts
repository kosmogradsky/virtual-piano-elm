export class Just<A> {
  constructor(readonly value: A) {}
}

class Nothing { }

const NOTHING = new Nothing();
export { NOTHING as Nothing }

export type Maybe<A> = Just<A> | Nothing;

export function fromNull<A>(value: A | null): Maybe<A> {
  return value === null ? NOTHING : new Just(value)
}

export function fromUndefined<A>(value: A | undefined): Maybe<A> {
  return value === undefined ? NOTHING : new Just(value)
}

export function fromNaN(value: number): Maybe<number> {
  return Number.isNaN(value) ? NOTHING : new Just(value)
}

export const map = <A, B>(mapper: (a: A) => B) => (maybe: Maybe<A>): Maybe<B> => {
  return maybe instanceof Nothing ? maybe : new Just(mapper(maybe.value))
}

export const flatMap = <A, B>(mapper: (a: A) => Maybe<B>) => (maybe: Maybe<A>): Maybe<B> => {
  return maybe instanceof Nothing ? maybe : mapper(maybe.value)
}

export const withDefault = <A>(defaultValue: A) => (maybe: Maybe<A>): A => {
  return maybe instanceof Nothing ? defaultValue : maybe.value
}