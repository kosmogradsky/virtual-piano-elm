export class Err<E> {
  constructor(readonly message: E) {}
}

export class Ok<A> {
  constructor(readonly value: A) {}
}

export type Result<E, A> = Err<E> | Ok<A>

export const map = <A, B>(mapper: (a: A) => B) => <E>(result: Result<E, A>): Result<E, B> => {
  return result instanceof Err ? result : new Ok(mapper(result.value))
}

export const flatMap = <E, A, B>(mapper: (a: A) => Result<E, B>) => (result: Result<E, A>): Result<E, B> => {
  return result instanceof Err ? result : mapper(result.value)
}

export const flatMapTo = <E, B>(nextResult: Result<E, B>) => flatMap(() => nextResult)

export const withDefault = <A>(defaultValue: A) => <E>(result: Result<E, A>): A => {
  return result instanceof Err ? defaultValue : result.value
}