// PWA via @ducanh2912/next-pwa (the maintained successor to next-pwa, which
// did not support Next 15). Same NetworkFirst/CacheFirst strategy as before;
// the workbox-level options (runtimeCaching, buildExcludes, skipWaiting) now
// live under workboxOptions.
const withPWA = require('@ducanh2912/next-pwa').default({
  dest: 'public',
  register: true,
  // Disabled in dev to avoid aggressive caching during hot-reload.
  disable: process.env.NODE_ENV === 'development',
  workboxOptions: {
    skipWaiting: true,
    clientsClaim: true,
    // Do not pre-cache API routes: too volatile and auth-dependent.
    exclude: [/middleware-manifest\.json$/, /app-build-manifest\.json$/],
    runtimeCaching: [
      {
        // App pages: NetworkFirst, fall back to cache when offline.
        urlPattern: ({ request, url }) =>
          request.mode === 'navigate' && !url.pathname.startsWith('/api/'),
        handler: 'NetworkFirst',
        options: {
          cacheName: 'pages',
          networkTimeoutSeconds: 4,
          expiration: { maxEntries: 50, maxAgeSeconds: 7 * 24 * 60 * 60 },
        },
      },
      {
        // GET API: NetworkFirst (programs, sessions, exercises change over time).
        urlPattern: ({ url, request }) =>
          url.pathname.startsWith('/api/') && request.method === 'GET',
        handler: 'NetworkFirst',
        options: {
          cacheName: 'api-get',
          networkTimeoutSeconds: 4,
          expiration: { maxEntries: 100, maxAgeSeconds: 24 * 60 * 60 },
        },
      },
      {
        // Static assets: CacheFirst (long-lived).
        urlPattern: ({ url }) =>
          url.pathname.startsWith('/_next/static/') ||
          /\.(?:png|svg|webp|ico|woff2?)$/.test(url.pathname),
        handler: 'CacheFirst',
        options: {
          cacheName: 'static-assets',
          expiration: { maxEntries: 200, maxAgeSeconds: 30 * 24 * 60 * 60 },
        },
      },
    ],
  },
});
const withNextIntl = require('next-intl/plugin')('./i18n/request.ts');

/** @type {import('next').NextConfig} */
const path = require('path');

const nextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  // The Cloudflare build (CF_BUILD=1) swaps in the workerd Prisma client, whose
  // wasm query compiler is imported statically (Workers disallow compiling wasm
  // at runtime). Every other build keeps the regular Node client.
  webpack(config, { webpack }) {
    if (process.env.CF_BUILD === '1') {
      // A replacement plugin rewrites the request before tsconfig-path
      // resolution, which a plain resolve.alias would lose to.
      config.plugins.push(
        new webpack.NormalModuleReplacementPlugin(
          /^@\/prisma\/generated\/client$/,
          path.resolve(__dirname, 'prisma/generated-worker/client.ts'),
        ),
      );
      // Leave the wasm import untouched for the OpenNext/esbuild step, which
      // knows how to load `.wasm?module` as a WebAssembly.Module on Workers.
      const wasmPath = path.resolve(
        __dirname,
        'prisma/generated-worker/internal/query_compiler_fast_bg.wasm?module',
      );
      config.externals = [
        ...(Array.isArray(config.externals) ? config.externals : [config.externals]),
        ({ request }, callback) => {
          if (request && /query_compiler_fast_bg\.wasm\?module$/.test(request)) {
            return callback(null, `import ${wasmPath}`);
          }
          callback();
        },
      ];
    }
    return config;
  },
};

module.exports = withPWA(withNextIntl(nextConfig));
