import { test, expect } from "@playwright/test";

test("reviewer completes intake, evidence review, approval and export", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/");
  await page
    .getByLabel("Password", { exact: true })
    .fill(process.env.DEMO_PASSWORD || "local-demo-password");
  await page.getByRole("button", { name: "Enter workspace" }).click();
  await expect(
    page.getByRole("heading", { name: "Clarity, before you commit." }),
  ).toBeVisible();
  await page.getByRole("button", { name: "New agreement" }).click();
  await page.getByRole("button", { name: "Load fictional sample" }).click();
  await expect(
    page.getByRole("heading", { name: "Northstar · Services agreement" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Approve agreement" }),
  ).toBeDisabled();
  await page.screenshot({
    path: "../docs/images/review-workspace.png",
    fullPage: true,
  });
  for (const label of [
    "Counterparty",
    "Effective date",
    "Renewal date",
    "Annual value",
    "Notice period",
  ]) {
    const field = page
      .locator(".field-card")
      .filter({ has: page.getByLabel(label, { exact: true }) });
    await field.getByRole("button", { name: "Accept", exact: true }).click();
    await expect(field.getByText("Accepted", { exact: true })).toBeVisible();
  }
  const missing = page
    .locator(".field-card")
    .filter({ has: page.getByLabel("Governing law", { exact: true }) });
  await missing
    .getByRole("textbox", { name: "Governing law review note" })
    .fill("Not stated in this fictional source document.");
  await missing.getByRole("button", { name: "Omit", exact: true }).click();
  await expect(missing.getByText("Omitted", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Approve agreement" }).click();
  await expect(
    page.getByText("Review complete", { exact: true }),
  ).toBeVisible();
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export CSV" }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toMatch(/clausedesk-\d+-review.csv/);
  await page.getByRole("button", { name: "Activity", exact: true }).click();
  await expect(
    page.getByText("Agreement approved", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Activity", exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({
    path: "../docs/images/review-mobile.png",
    fullPage: true,
  });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBeTruthy();
  expect(errors).toEqual([]);
});

test("public demo isolates visitors and supports the complete sample review", async ({
  page,
  browser,
}) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Try a private demo" }).click();
  await expect(
    page.getByRole("heading", { name: "Clarity, before you commit." }),
  ).toBeVisible();
  await page.locator(".doc-row").first().click();
  await expect(
    page.getByRole("heading", { name: "Northstar · Services agreement" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Extract with AI" }),
  ).toHaveCount(0);
  const firstToken = await page.evaluate(() =>
    sessionStorage.getItem("clausedesk.token"),
  );
  const docs = await page.request.get("/api/documents", {
    headers: { Authorization: `Bearer ${firstToken}` },
  });
  const firstId = (await docs.json()).documents[0].id;
  const other = await browser.newContext();
  const second = await other.newPage();
  await second.goto("/");
  await second.getByRole("button", { name: "Try a private demo" }).click();
  await expect(
    second.getByRole("heading", { name: "Clarity, before you commit." }),
  ).toBeVisible();
  const secondToken = await second.evaluate(() =>
    sessionStorage.getItem("clausedesk.token"),
  );
  const denied = await second.request.get(`/api/documents/${firstId}`, {
    headers: { Authorization: `Bearer ${secondToken}` },
  });
  expect(denied.status()).toBe(404);
  await other.close();
  for (const label of [
    "Counterparty",
    "Effective date",
    "Renewal date",
    "Annual value",
    "Notice period",
  ]) {
    const field = page
      .locator(".field-card")
      .filter({ has: page.getByLabel(label, { exact: true }) });
    await field.getByRole("button", { name: "Accept", exact: true }).click();
    await expect(field.getByText("Accepted", { exact: true })).toBeVisible();
  }
  const missing = page
    .locator(".field-card")
    .filter({ has: page.getByLabel("Governing law", { exact: true }) });
  await missing
    .getByRole("textbox", { name: "Governing law review note" })
    .fill("Not stated in source.");
  await missing.getByRole("button", { name: "Omit", exact: true }).click();
  await page.getByRole("button", { name: "Approve agreement" }).click();
  await expect(
    page.getByText("Review complete", { exact: true }),
  ).toBeVisible();
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export CSV" }).click();
  expect((await downloadPromise).suggestedFilename()).toMatch(
    /clausedesk-\d+-review.csv/,
  );
  await page.getByRole("button", { name: "New agreement" }).click();
  await expect(page.getByLabel("Document file")).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Load fictional sample" }),
  ).toBeVisible();
});
