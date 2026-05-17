/** @returns listings (possibly empty) or throws (including timeout:${label}) */
export function withTimeout<T>(
  ms: number,
  label: string,
  fn: () => Promise<T>
): Promise<T> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(
      () => reject(new Error(`timeout:${label}`)),
      ms
    );
    fn()
      .then((v) => {
        clearTimeout(t);
        resolve(v);
      })
      .catch((e) => {
        clearTimeout(t);
        reject(e);
      });
  });
}

export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
