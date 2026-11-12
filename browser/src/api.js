// Calls to the Fortiva backend, the ones the app makes, as the browser
// extension makes them. The extension sends no events: the backend reads
// /devices/{id}/events as phone events, for its alerts and dashboards.

export const API_BASE = 'https://api.fortivavpn.com';

// The app gives one call 10 seconds (ApiConfig.timeout).
const TIMEOUT_MS = 10000;

// ApiError is an answer from the backend that was not a success, or a call
// that got no answer (status 0). reason is the backend's detail.reason when
// it sent one, as the payment calls do ({"detail": {"reason": "expired"}}).
export class ApiError extends Error {
  constructor(status, reason, message) {
    super(message || `backend answered ${status}${reason ? ` (${reason})` : ''}`);
    this.status = status;
    this.reason = reason || '';
  }
}

export class Api {
  // fetchImpl and base are for tests.
  constructor({ version, fetchImpl = globalThis.fetch.bind(globalThis), base = API_BASE, timeoutMs = TIMEOUT_MS }) {
    this.version = version;
    this.fetch = fetchImpl;
    this.base = base;
    this.timeoutMs = timeoutMs;
  }

  async post(path, body) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), this.timeoutMs);
    let res;
    try {
      res = await this.fetch(this.base + path, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          // The headers every app call carries (ApiClient in the app).
          'X-App-Version': this.version,
          'X-App-Platform': 'browser',
        },
        body: JSON.stringify(body),
        cache: 'no-store',
        credentials: 'omit',
        signal: ctrl.signal,
      });
    } catch (e) {
      throw new ApiError(0, 'network', String(e && e.message || e));
    } finally {
      clearTimeout(timer);
    }
    let data = null;
    try {
      data = await res.json();
    } catch {
      data = null;
    }
    if (!res.ok) {
      const detail = data && data.detail;
      const reason = detail && typeof detail === 'object' && typeof detail.reason === 'string' ? detail.reason : '';
      throw new ApiError(res.status, reason);
    }
    return data;
  }

  register(body) {
    return this.post('/api/v1/devices/register', { ...body, platform: 'browser', app_version: this.version });
  }

  // The proxies this browser may use, its credentials and its allowance.
  async browserConfigs(deviceId) {
    const data = await this.post('/api/v1/configs/browser', { device_id: deviceId });
    if (!data || !Array.isArray(data.proxies) || typeof data.quota !== 'object' || data.quota === null) {
      throw new ApiError(0, 'format', 'the backend sent an answer without proxies or quota');
    }
    return data;
  }

  redeem(deviceId, code) {
    return this.post(`/api/v1/devices/${encodeURIComponent(deviceId)}/billing/redeem`, { code });
  }
}
