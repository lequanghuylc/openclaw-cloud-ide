function envValue(env, key) {
  const value = env[key];
  if (value == null) return "";
  return String(value).trim();
}

function removeOpenAIConfigWhenKeyIsBlank(cfg, env) {
  if (envValue(env, "OPENAI_API_KEY") !== "") {
    return;
  }

  delete cfg.models?.providers?.openai;
  delete cfg.plugins?.entries?.openai;
}

export function applyCustomProviderFromEnv(cfg, env = process.env) {
  removeOpenAIConfigWhenKeyIsBlank(cfg, env);

  const providerName = envValue(env, "CUSTOM_PROVIDER_NAME");
  const apiKey = envValue(env, "CUSTOM_PROVIDER_API_KEY");
  const baseUrl = envValue(env, "CUSTOM_PROVIDER_BASE_URL");
  const modelId = envValue(env, "CUSTOM_PROVIDER_MODEL_ID");

  if (providerName === "" || apiKey === "" || baseUrl === "" || modelId === "") {
    return false;
  }

  const providerApi = envValue(env, "CUSTOM_PROVIDER_API") || "openai-completions";
  const modelApi = envValue(env, "CUSTOM_PROVIDER_MODEL_API") || providerApi;
  const modelName = envValue(env, "CUSTOM_PROVIDER_MODEL_NAME") || modelId;

  cfg.models ??= {};
  cfg.models.providers ??= {};
  cfg.models.providers[providerName] = {
    baseUrl,
    apiKey,
    auth: envValue(env, "CUSTOM_PROVIDER_AUTH") || "api-key",
    api: providerApi,
    models: [
      {
        id: modelId,
        name: modelName,
        api: modelApi,
      },
    ],
  };

  cfg.agents ??= {};
  cfg.agents.defaults ??= {};
  cfg.agents.defaults.model ??= {};
  cfg.agents.defaults.model.primary = `${providerName}/${modelId}`;

  return true;
}
