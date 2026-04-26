import assert from "node:assert/strict";
import test from "node:test";

import { applyCustomProviderFromEnv } from "../bootstrap-openclaw-config.mjs";

test("adds a generic custom provider from environment variables", () => {
  const cfg = {
    agents: { defaults: { model: { primary: "openai/gpt-5.4" } } },
    models: { providers: { openai: { models: [] } } },
  };

  applyCustomProviderFromEnv(cfg, {
    CUSTOM_PROVIDER_NAME: "krouter",
    CUSTOM_PROVIDER_API_KEY: "test-key",
    CUSTOM_PROVIDER_BASE_URL: "https://api.krouter.net/v1",
    CUSTOM_PROVIDER_MODEL_ID: "cx/gpt-5.5",
  });

  assert.deepEqual(cfg.models.providers.krouter, {
    baseUrl: "https://api.krouter.net/v1",
    apiKey: "test-key",
    auth: "api-key",
    api: "openai-completions",
    models: [
      {
        id: "cx/gpt-5.5",
        name: "cx/gpt-5.5",
        api: "openai-completions",
      },
    ],
  });
  assert.equal(cfg.agents.defaults.model.primary, "krouter/cx/gpt-5.5");
});

test("does not add a custom provider unless all required environment variables are set", () => {
  const cfg = { models: { providers: {} } };

  applyCustomProviderFromEnv(cfg, {
    CUSTOM_PROVIDER_NAME: "krouter",
    CUSTOM_PROVIDER_API_KEY: "test-key",
    CUSTOM_PROVIDER_BASE_URL: "https://api.krouter.net/v1",
  });

  assert.equal(cfg.models.providers.krouter, undefined);
});

test("removes the OpenAI provider when OpenAI API key is missing and a custom provider is configured", () => {
  const cfg = {
    agents: { defaults: { model: { primary: "openai/gpt-5.4" } } },
    models: {
      providers: {
        openai: {
          baseUrl: "https://api.openai.com/v1",
          models: [{ id: "openai:gpt-5.4", name: "OpenAI GPT-5.4" }],
        },
      },
    },
    plugins: { entries: { openai: { enabled: true } } },
  };

  applyCustomProviderFromEnv(cfg, {
    CUSTOM_PROVIDER_NAME: "krouter",
    CUSTOM_PROVIDER_API_KEY: "test-key",
    CUSTOM_PROVIDER_BASE_URL: "https://api.krouter.net/v1",
    CUSTOM_PROVIDER_MODEL_ID: "cx/gpt-5.5",
  });

  assert.equal(cfg.models.providers.openai, undefined);
  assert.equal(cfg.plugins.entries.openai, undefined);
  assert.equal(cfg.agents.defaults.model.primary, "krouter/cx/gpt-5.5");
});
