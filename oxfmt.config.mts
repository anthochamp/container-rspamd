import config from "@ac-kit/oxlint-config/oxfmt";
import { defineConfig } from "oxfmt";

export default defineConfig({
	...config,
	ignorePatterns: [...(config.ignorePatterns ?? []), "**/*.inc"],
});
