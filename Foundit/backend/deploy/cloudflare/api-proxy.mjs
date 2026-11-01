export default {
  async fetch(request, env) {
    if (!env.ORIGIN_PROXY_SECRET || !env.RENDER_ORIGIN) return new Response('Service unavailable', { status: 503 });
    const target = new URL(env.RENDER_ORIGIN);
    if (target.protocol !== 'https:' || !target.hostname.endsWith('.onrender.com')) return new Response('Service unavailable', { status: 503 });
    const incoming = new URL(request.url);
    target.pathname = incoming.pathname;
    target.search = incoming.search;
    const headers = new Headers(request.headers);
    headers.set('x-foundit-origin-token', env.ORIGIN_PROXY_SECRET);
    headers.set('x-foundit-client-ip', request.headers.get('cf-connecting-ip') || '');
    headers.delete('host');
    return fetch(new Request(target, { method: request.method, headers, body: request.body, redirect: 'manual' }));
  }
};
