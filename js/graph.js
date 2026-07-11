// Microsoft Graph helpers for THE Intune Dashboard.
// Depends at call-time on getToken() defined in the main page script
// (and optionally opts.token for just-in-time write scopes).

// Prefer large pages when the caller did not set $top — fewer round-trips
// on managedDevices / devices / mobileApps (Graph caps vary; 999 is widely accepted).
function graphPathWithTop(path, top = 999) {
  if (!path || /[?&]\$top=/i.test(path)) return path;
  return path + (path.includes('?') ? '&' : '?') + '$top=' + top;
}

// Fetch with retry on Graph throttling (429) and transient 503/504, honoring Retry-After.
async function graphFetch(url, init = {}) {
  for (let attempt = 0; ; attempt++) {
    if (init.signal && init.signal.aborted) {
      const err = new Error('Aborted');
      err.name = 'AbortError';
      throw err;
    }
    const res = await fetch(url, init);
    if ((res.status !== 429 && res.status !== 503 && res.status !== 504) || attempt >= 3) return res;
    const retryAfter = parseInt(res.headers.get('Retry-After'), 10);
    const waitMs = (isNaN(retryAfter) ? Math.pow(2, attempt + 1) : Math.min(retryAfter, 60)) * 1000;
    console.warn(`Graph ${res.status} on ${url.split('?')[0]} — retrying in ${waitMs / 1000}s (attempt ${attempt + 1}/3)`);
    await new Promise((r, reject) => {
      const t = setTimeout(r, waitMs);
      if (init.signal) {
        init.signal.addEventListener('abort', () => {
          clearTimeout(t);
          const err = new Error('Aborted');
          err.name = 'AbortError';
          reject(err);
        }, { once: true });
      }
    });
  }
}

function graphAuthHeaders(token, extra) {
  const headers = { Authorization: 'Bearer ' + token };
  if (extra) Object.assign(headers, extra);
  return headers;
}

function graphHttpError(res, bodyText) {
  const err = new Error('Graph ' + res.status + ': ' + bodyText);
  err.status = res.status;
  err.body = bodyText;
  if (/x-msft-approval-justification/.test(bodyText)) err.isMaa = true;
  return err;
}

async function graphGet(path, opts = {}) {
  const token = opts.token || await getToken();
  const res = await graphFetch('https://graph.microsoft.com/' + path, {
    headers: graphAuthHeaders(token, opts.headers),
    signal: opts.signal
  });
  if (!res.ok) throw graphHttpError(res, await res.text());
  return res.json();
}

async function graphPost(path, body, opts = {}) {
  const token = opts.token || await getToken();
  const res = await graphFetch('https://graph.microsoft.com/' + path, {
    method: 'POST',
    headers: graphAuthHeaders(token, Object.assign({ 'Content-Type': 'application/json' }, opts.headers || {})),
    body: JSON.stringify(body),
    signal: opts.signal
  });
  if (!res.ok) throw graphHttpError(res, await res.text());
  if (res.status === 204) return null;
  const text = await res.text();
  if (!text) return null;
  try { return JSON.parse(text); } catch { return null; }
}

async function graphPatch(path, body, opts = {}) {
  const token = opts.token || await getToken();
  const res = await graphFetch('https://graph.microsoft.com/' + path, {
    method: 'PATCH',
    headers: graphAuthHeaders(token, Object.assign({ 'Content-Type': 'application/json' }, opts.headers || {})),
    body: JSON.stringify(body),
    signal: opts.signal
  });
  if (!res.ok) throw graphHttpError(res, await res.text());
  if (res.status === 204) return null;
  const text = await res.text();
  if (!text) return null;
  try { return JSON.parse(text); } catch { return null; }
}

async function graphDelete(path, opts = {}) {
  const token = opts.token || await getToken();
  const res = await graphFetch('https://graph.microsoft.com/' + path, {
    method: 'DELETE',
    headers: graphAuthHeaders(token, opts.headers),
    signal: opts.signal
  });
  if (res.ok || res.status === 404) return;
  throw graphHttpError(res, await res.text());
}

// Paginate a Graph collection. Injects $top=999 unless the path already sets $top.
// opts.onPage(accumulatedCount, pageSize) for progress UIs.
async function graphGetAll(initialPath, opts = {}) {
  let path = graphPathWithTop(initialPath);
  const all = [];
  while (path) {
    if (opts.signal && opts.signal.aborted) {
      const err = new Error('Aborted');
      err.name = 'AbortError';
      throw err;
    }
    const data = await graphGet(path, opts);
    if (data.value) all.push(...data.value);
    if (opts.onPage) opts.onPage(all.length, (data.value || []).length);
    const next = data['@odata.nextLink'];
    path = next ? next.replace('https://graph.microsoft.com/', '') : null;
  }
  return all;
}

// Bounded concurrency — used for per-device RAM fan-out and similar.
// opts.signal: AbortSignal — workers stop claiming new items when aborted.
async function mapPool(items, concurrency, fn, opts = {}) {
  if (!items.length) return [];
  const signal = opts.signal;
  const results = new Array(items.length);
  let next = 0;
  function throwIfAborted() {
    if (signal && signal.aborted) {
      const err = new Error('Aborted');
      err.name = 'AbortError';
      throw err;
    }
  }
  async function worker() {
    for (;;) {
      throwIfAborted();
      const i = next++;
      if (i >= items.length) return;
      results[i] = await fn(items[i], i);
    }
  }
  const n = Math.min(concurrency, items.length);
  await Promise.all(Array.from({ length: n }, () => worker()));
  return results;
}
