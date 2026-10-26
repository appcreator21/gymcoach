import { PrismaClient } from '@/prisma/generated/client';
import { PrismaPg } from '@prisma/adapter-pg';

// Singleton pattern recommended by Prisma in dev (avoids
// multiple connections on Next.js hot-reload).
// https://www.prisma.io/docs/orm/more/help-and-troubleshooting/help-articles/nextjs-prisma-client-dev-practices
//
// Prisma 7 removed the bundled Rust query engine: the client now talks to
// PostgreSQL through a JavaScript driver adapter, so we hand it a pg-backed
// PrismaPg adapter built from DATABASE_URL.
//
// On Cloudflare Workers (OpenNext) a connection cannot outlive the request
// that opened it, so there the client is built per request from the
// HYPERDRIVE binding instead of being a process-wide singleton.

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

interface WorkerContext {
  env?: { HYPERDRIVE?: { connectionString: string } };
  ctx?: object;
}

// OpenNext publishes the Worker env/ctx under this well-known symbol. Reading
// it directly keeps Node-only runs (tests, Docker) free of the adapter import.
function workerContext(): WorkerContext | undefined {
  return (globalThis as Record<symbol, WorkerContext | undefined>)[
    Symbol.for('__cloudflare-context__')
  ];
}

const log = process.env.NODE_ENV === 'development' ? (['query', 'error', 'warn'] as const) : (['error'] as const);

function createClient(connectionString: string | undefined): PrismaClient {
  const adapter = new PrismaPg({ connectionString });
  return new PrismaClient({ adapter, log: [...log] });
}

const perRequest = new WeakMap<object, PrismaClient>();

function resolveClient(): PrismaClient {
  const hyperdrive = workerContext()?.env?.HYPERDRIVE;
  const ctx = workerContext()?.ctx;
  if (hyperdrive && ctx) {
    let client = perRequest.get(ctx);
    if (!client) {
      client = createClient(hyperdrive.connectionString);
      perRequest.set(ctx, client);
    }
    return client;
  }
  globalForPrisma.prisma ??= createClient(process.env.DATABASE_URL);
  return globalForPrisma.prisma;
}

// Lazy proxy so importing this module never opens a connection and every
// access picks the client that belongs to the current request.
export const db: PrismaClient = new Proxy({} as PrismaClient, {
  get(_target, prop) {
    const client = resolveClient();
    const value = Reflect.get(client, prop, client);
    return typeof value === 'function' ? value.bind(client) : value;
  },
});
