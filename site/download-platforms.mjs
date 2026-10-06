export const DOWNLOAD_PLATFORMS = Object.freeze({
  macos: Object.freeze({
    platform: 'macos', version: '1.0.0', analyticsPlatform: 'macos_arm64',
    formId: '0a702231-3472-412f-8e3b-00ecfa481100',
    formUrl: 'https://cfgauss.com.br/t/formembed-download-resenha-para-macos-2e57ed14',
    redirectUrl: 'https://cfgauss.com.br/t/formredirect-0a702231-3472-412f-8e3b-00ecfa481100',
    embedOrigin: 'https://cfgauss.com.br', artifactExtension: '.dmg',
  }),
  // Populated only from a separately provisioned and verified CF Gauss form.
  windows: null,
});

export function platformConfig(platform) {
  const config = Object.hasOwn(DOWNLOAD_PLATFORMS, platform) ? DOWNLOAD_PLATFORMS[platform] : null;
  return config ? Object.freeze({ ...config }) : null;
}
