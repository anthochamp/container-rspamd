import * as path from "node:path";

import type { DockerContainerRunOptions } from "@ac-kit/cmd-docker";
import { getRandomEphemeralPort } from "@ac-kit/core";
import type { EnvVariables } from "@ac-kit/format-shell";
import { initDockerSuite } from "@ac-kit/integration-test-util";
import { isHttpAvailable } from "@ac-kit/net-http";
import { beforeAll, vi } from "vitest";

const srcPath = path.resolve(path.join(__dirname, "..", "src"));

const RSPAMD_CONTROLLER_PORT = 11334;

type ContainerRunOptions = Omit<
	DockerContainerRunOptions,
	"name" | "context" | "detach"
>;

export function initSuite() {
	let pendingRunOptions: ContainerRunOptions = {};
	let pendingUrl = "";

	const { containerImageName } = initDockerSuite(srcPath, {
		containerNamePrefix: "test-rspamd-",
		containerRunOptions: () => pendingRunOptions,
		onContainerStarted: async () => {
			await vi.waitUntil(() => isHttpAvailable(pendingUrl), {
				timeout: 30_000,
				interval: 500,
			});
		},
	});

	return {
		containerImageName,
		/** Registers the container's env for every test in this describe. */
		useContainer: (env?: EnvVariables) => {
			const hostPort = getRandomEphemeralPort();
			const url = `http://127.0.0.1:${hostPort}`;

			beforeAll(() => {
				pendingRunOptions = {
					publish: [`${hostPort}:${RSPAMD_CONTROLLER_PORT}`],
					env,
				};
				pendingUrl = url;
			});

			return { url };
		},
	};
}
