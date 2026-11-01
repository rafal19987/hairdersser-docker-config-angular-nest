import { expect } from '@playwright/test';
import { MAILPIT_URL } from './environment';

interface MailSummary {
  ID: string;
  Subject: string;
  To: { Address: string }[];
}

const findMessage = async (to: string, subject: string) => {
  const response = await fetch(`${MAILPIT_URL}/api/v1/messages?limit=200`);
  const { messages } = (await response.json()) as { messages: MailSummary[] };

  return messages.find(
    message =>
      message.Subject.startsWith(subject) &&
      message.To.some(recipient => recipient.Address === to),
  );
};

// Mails are sent asynchronously after the request, so poll until one arrives
export const waitForMail = async (to: string, subject: string) => {
  let found: MailSummary | undefined;

  await expect
    .poll(async () => (found = await findMessage(to, subject)), {
      message: `mail "${subject}" to ${to}`,
      timeout: 15_000,
    })
    .toBeTruthy();

  const response = await fetch(`${MAILPIT_URL}/api/v1/message/${found!.ID}`);
  return (await response.json()) as { Subject: string; HTML: string };
};

// Links in mail HTML have escaped slashes, e.g. http:&#x2F;&#x2F;localhost
export const linkFrom = (html: string, pathPart: string): string => {
  const links = [...html.matchAll(/href="([^"]+)"/g)].map(match =>
    match[1].replace(/&#x2F;/g, '/').replace(/&amp;/g, '&'),
  );
  const link = links.find(href => href.includes(pathPart));

  if (!link) throw new Error(`No link containing "${pathPart}" in the mail`);
  return link;
};
