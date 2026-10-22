// XMLHttpRequest wrapper. Chrome 53 has fetch() but no AbortController, so
// XHR gives us timeouts and cancellation.

export class HttpError extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

export interface Request<T> {
  promise: Promise<T>;
  abort(): void;
}

export function getText(url: string, timeoutMs = 20000): Request<string> {
  const xhr = new XMLHttpRequest();
  const promise = new Promise<string>((resolve, reject) => {
    xhr.open('GET', url, true);
    xhr.timeout = timeoutMs;
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) resolve(xhr.responseText);
      else reject(new HttpError(`HTTP ${xhr.status}`, xhr.status));
    };
    xhr.onerror = () => reject(new HttpError('network', 0));
    xhr.ontimeout = () => reject(new HttpError('timeout', 0));
    xhr.onabort = () => reject(new HttpError('aborted', -1));
    xhr.send();
  });
  return { promise, abort: () => xhr.abort() };
}
