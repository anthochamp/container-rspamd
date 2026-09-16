import { expect, describe, it } from "vitest";

import { initSuite } from "./common";

describe("controller", () => {
	const { useContainer } = initSuite();

	describe("default configuration", () => {
		const { url } = useContainer();

		it("responds with pong on /ping", async () => {
			const response = await fetch(`${url}/ping`);

			expect(response.status).toBe(200);
			const body = await response.text();
			expect(body.trim()).toBe("pong");
		});

		it("allows unauthenticated access to /stat when no password is configured", async () => {
			const response = await fetch(`${url}/stat`);

			expect(response.status).toBe(200);
		});
	});

	describe("with RSPAMD_CONTROLLER_PASSWORD set", () => {
		const { url } = useContainer({ RSPAMD_CONTROLLER_PASSWORD: "test-secret" });

		it("requires authentication on /stat", async () => {
			const unauthenticated = await fetch(`${url}/stat`);
			expect(unauthenticated.status).toBe(401);
		});
	});
});
