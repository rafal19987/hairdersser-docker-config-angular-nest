import { defineConfig } from '@playwright/test';

// Runs against the test environment: bash scripts/test-env.sh up
export default defineConfig({
  testDir: './tests',
  // The tests share one database and one mailbox
  workers: 1,
  fullyParallel: false,
  retries: 0,
  timeout: 120_000,
  expect: { timeout: 15_000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    channel: 'chrome',
    locale: 'pl-PL',
    timezoneId: 'Europe/Warsaw',
    viewport: { width: 1440, height: 900 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
});
