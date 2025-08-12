// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'AudioCap Recorder Docs',
  url: 'https://example.com',
  baseUrl: '/',
  favicon: 'img/favicon.ico',
  organizationName: 'audiocap',
  projectName: 'recorder',
  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */ ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          path: '../Docs',
          routeBasePath: '/',
          includeCurrentVersion: true,
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],
  staticDirectories: ['static'],
  themeConfig: {
    navbar: {
      title: 'AudioCap Recorder',
      items: [
        {
          type: 'html',
          position: 'right',
          value: '<div id="version-switcher" style="min-width:160px"></div>'
        }
      ]
    }
  },
  scripts: ['/js/version-switcher.js']
};

module.exports = config;
