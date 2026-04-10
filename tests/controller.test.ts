import { expect, suite, test } from "vitest";
import { initSuite } from "./common";

suite.sequential("controller", () => {
	const { startContainer } = initSuite();

	test("responds with pong on /ping", async () => {
		const { url } = await startContainer();

		const response = await fetch(`${url}/ping`);

		expect(response.status).toBe(200);
		const body = await response.text();
		expect(body.trim()).toBe("pong");
	});

	test("allows unauthenticated access to /stat when no password is configured", async () => {
		const { url } = await startContainer();

		const response = await fetch(`${url}/stat`);

		expect(response.status).toBe(200);
	});

	test("requires authentication on /stat when RSPAMD_CONTROLLER_PASSWORD is set", async () => {
		const { url } = await startContainer({
			env: { RSPAMD_CONTROLLER_PASSWORD: "test-secret" },
		});

		const unauthenticated = await fetch(`${url}/stat`);
		expect(unauthenticated.status).toBe(401);
	});
});
