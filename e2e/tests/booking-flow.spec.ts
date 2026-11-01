import { expect, Page, test } from '@playwright/test';
import {
  ADMIN_URL,
  EMPLOYEE_EMAIL,
  RECEPTION,
  WEBSITE_URL,
} from '../support/environment';
import { linkFrom, waitForMail } from '../support/mailpit';

const DAY_MS = 24 * 60 * 60 * 1000;

// Unique per run, so the test never needs a database reset
const runId = Date.now().toString(36);
const client = {
  firstName: 'Ola',
  lastName: `Test${runId}`,
  email: `e2e-${runId}@example.com`,
  password: 'Haslo12345!',
};
const clientName = `${client.firstName} ${client.lastName}`;

const mondayOf = (date: Date) => {
  const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  return monday;
};

// Picks a day after today with a free slot and returns it as YYYY-MM-DD
const pickDayWithFreeSlot = async (page: Page) => {
  const openDays = page.getByRole('button', {
    name: /^(pon|wt|śr|czw|pt|sob) \d+ \S+$/,
  });

  for (let index = 1; index < 6; index++) {
    await openDays.nth(index).click();
    const firstSlot = page.getByRole('button', { name: /^\d{2}:\d{2}$/ }).first();
    const noSlots = page.getByText('Brak wolnych terminów w tym dniu');
    await expect(firstSlot.or(noSlots)).toBeVisible();

    if (await firstSlot.isVisible()) {
      await firstSlot.click();
      return new URL(page.url()).searchParams.get('date')!;
    }
  }

  throw new Error('No free slot with Anna Nowak in the next days');
};

test('client books online and reception confirms the visit', async ({
  page,
  browser,
}) => {
  await test.step('client registers on the website', async () => {
    await page.goto(`${WEBSITE_URL}/konto`);
    await page.getByRole('tab', { name: 'Rejestracja' }).click();
    await page.getByRole('textbox', { name: 'Imię' }).fill(client.firstName);
    await page
      .getByRole('textbox', { name: 'Nazwisko (opcjonalnie)' })
      .fill(client.lastName);
    await page.getByRole('textbox', { name: 'Email' }).fill(client.email);
    await page
      .getByRole('textbox', { name: /^Hasło/ })
      .fill(client.password);
    await page
      .getByRole('textbox', { name: 'Powtórz hasło' })
      .fill(client.password);
    await page.getByRole('button', { name: 'Załóż konto' }).click();

    await expect(page.getByText('Konto zostało utworzone')).toBeVisible();
  });

  await test.step('client activates the account from the mail', async () => {
    const mail = await waitForMail(client.email, 'Potwierdź swój adres email');
    await page.goto(linkFrom(mail.HTML, '/konto/weryfikacja/'));

    await expect(page.getByText('Konto jest aktywne')).toBeVisible();
  });

  await test.step('client logs in', async () => {
    await page.goto(`${WEBSITE_URL}/konto`);
    await page.getByRole('textbox', { name: 'Email' }).fill(client.email);
    await page.getByRole('textbox', { name: 'Hasło' }).fill(client.password);
    await page.getByRole('button', { name: 'Zaloguj się' }).last().click();

    await expect(
      page.getByRole('heading', { name: `Cześć, ${client.firstName}` }),
    ).toBeVisible();
  });

  let bookingDate = '';

  await test.step('client books a haircut with Anna Nowak', async () => {
    await page.goto(`${WEBSITE_URL}/book`);
    await page.getByRole('button', { name: /^Strzyżenie damskie/ }).click();
    await page.getByRole('button', { name: /^Anna Nowak/ }).click();
    bookingDate = await pickDayWithFreeSlot(page);

    await expect(page.getByText(`Rezerwujesz jako ${clientName}`)).toBeVisible();
    await page
      .getByRole('textbox', { name: 'Uwagi do wizyty (opcjonalnie)' })
      .fill('Test e2e');
    await page.getByRole('button', { name: 'Zarezerwuj wizytę' }).last().click();

    await expect(page.getByText('Dziękujemy!')).toBeVisible();
  });

  await test.step('client and employee get booking mails', async () => {
    await waitForMail(client.email, 'Potwierdzenie rezerwacji');
    await waitForMail(EMPLOYEE_EMAIL, 'Nowa rezerwacja');
  });

  await test.step('reception confirms the visit in the calendar', async () => {
    const reception = await browser.newContext();
    const admin = await reception.newPage();

    await admin.goto(`${ADMIN_URL}/login`);
    await admin.getByRole('textbox', { name: 'Login:' }).fill(RECEPTION.email);
    await admin.getByRole('textbox', { name: 'Hasło:' }).fill(RECEPTION.password);
    await admin.getByRole('button', { name: 'Zaloguj' }).click();
    await admin.waitForURL('**/dashboard**');
    await admin.getByRole('link', { name: 'Kalendarz' }).click();

    // The week view opens on the current week
    const weeksAhead = Math.round(
      (mondayOf(new Date(`${bookingDate}T12:00:00`)).getTime() -
        mondayOf(new Date()).getTime()) /
        (7 * DAY_MS),
    );
    // The header arrows are icon-only buttons without a label: today, previous, next
    const nextWeek = admin.locator('app-calendar-header button').nth(2);
    for (let week = 0; week < weeksAhead; week++) {
      await nextWeek.click();
    }

    await admin
      .locator('app-calendar-week-view')
      .getByText(clientName)
      .click();
    const details = admin.locator('app-appointment-details');
    await expect(details.getByText('Oczekuje na potwierdzenie')).toBeVisible();
    await expect(details.getByText('Test e2e')).toBeVisible();

    await details.getByRole('button', { name: 'Potwierdź' }).click();

    await expect(details.getByText('Potwierdzona', { exact: true })).toBeVisible();
    await reception.close();
  });

  await test.step('client gets the confirmation and sees it in the account', async () => {
    await waitForMail(client.email, 'Wizyta potwierdzona');

    await page.goto(`${WEBSITE_URL}/konto`);
    await expect(page.getByText('Potwierdzona', { exact: true })).toBeVisible();
  });
});
