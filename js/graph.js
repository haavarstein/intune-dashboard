// Microsoft Graph helpers for THE Intune Dashboard.
// Depends at call-time on getToken() defined in the main page script
// (and optionally opts.token for just-in-time write scopes).

// Fetch with retry on Graph throttling (429) and transient 503/504, honoring Retry-After.
async function graphFetch(url, init) {
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(url, init);
    if ((res.status !== 429 && res.status !== 503 && res.status !== 504) || attempt >= 3) return res;
    const retryAfter = parseInt(res.headers.get('Retry-After'), 10);
    const waitMs = (isNaN(retryAfter) ? Math.pow(2, attempt + 1) : Math.min(retryAfter, 60)) * 1000;
    console.warn(`Graph ${res.status} on ${url.split('?')[0]} — retrying in ${waitMs / 1000}s (attempt ${attempt + 1}/3)`);
    await new Promise(r => setTimeout(r, waitMs));
  }
}

async function graphGet(path, opts = {}) {
  const token = opts.token || await getToken();
  const headers = { Authorization: 'Bearer ' + token };
  if (opts.headers) Object.assign(headers, opts.headers);
  const res = await graphFetch('https://graph.microsoft.com/' + path, { headers });
  if (!res.ok) {
    const bodyText = await res.text();
    const err = new Error('Graph ' + res.status + ': ' + bodyText);
    err.status = res.status;
    err.body = bodyText;
    if (/x-msft-approval-justification/.test(bodyText)) err.isMaa = true;
    throw err;
  }
  return res.json();
}

async function graphPost(path, body, opts = {}) {
  const token = opts.token || await getToken();
  const headers = { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' };
  if (opts.headers) Object.assign(headers, opts.headers);
  const res = await graphFetch('https://graph.microsoft.com/' + path, {
    method: 'POST',
    headers,
    body: JSON.stringify(body)
  });
  if (!res.ok) {
    const bodyText = await res.text();
    const err = new Error('Graph ' + res.status + ': ' + bodyText);
    err.status = res.status;
    err.body = bodyText;
    if (/x-msft-approval-justification/.test(bodyText)) err.isMaa = true;
    throw err;
  }
  // Some action endpoints (e.g. .../assign) return 204 No Content with an empty body.
  // .json() on an empty body throws "Unexpected end of JSON input" — handle that.
  if (res.status === 204) return null;
  const text = await res.text();
  if (!text) return null;
  try { return JSON.parse(text); } catch { return null; }
}

async function graphPatch(path, body, opts = {}) {
  const token = opts.token || await getToken();
  const headers = { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' };
  if (opts.headers) Object.assign(headers, opts.headers);
  const res = await graphFetch('https://graph.microsoft.com/' + path, {
    method: 'PATCH',
    headers,
    body: JSON.stringify(body)
  });
  if (!res.ok) {
    const bodyText = await res.text();
    const err = new Error('Graph ' + res.status + ': ' + bodyText);
    err.status = res.status;
    err.body = bodyText;
    if (/x-msft-approval-justification/.test(bodyText)) err.isMaa = true;
    throw err;
  }
  if (res.status === 204) return null;
  const text = await res.text();
  if (!text) return null;
  try { return JSON.parse(text); } catch { return null; }
}

async function graphDelete(path, opts = {}) {
  const token = opts.token || await getToken();
  const headers = { Authorization: 'Bearer ' + token };
  if (opts.headers) Object.assign(headers, opts.headers);
  const res = await graphFetch('https://graph.microsoft.com/' + path, {
    method: 'DELETE',
    headers
  });
  if (res.ok || res.status === 404) return;
  const body = await res.text();
  const err = new Error('Graph ' + res.status + ': ' + body);
  err.status = res.status;
  err.body = body;
  if (/x-msft-approval-justification/.test(body)) err.isMaa = true;
  throw err;
}

async function graphGetAll(initialPath) {
  let path = initialPath;
  const all = [];
  while (path) {
    const data = await graphGet(path);
    if (data.value) all.push(...data.value);
    const next = data['@odata.nextLink'];
    path = next ? next.replace('https://graph.microsoft.com/', '') : null;
  }
  return all;
}
