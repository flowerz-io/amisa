/**
 * Timeout réseau : Promise.race — ne résout pas « instantanément » sans travail async réel.
 */
export async function withTimeoutPromise<T>(
  promise: Promise<T>,
  ms: number,
  providerName: string
): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout>;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`${providerName} timeout after ${ms}ms`));
    }, ms);
  });
  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId!);
  }
}

/**
 * Lance `fn()` et borne la durée totale (identique à race sur la promesse retournée).
 */
export function withTimeout<T>(
  ms: number,
  label: string,
  fn: () => Promise<T>
): Promise<T> {
  return withTimeoutPromise(fn(), ms, label);
}

export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
